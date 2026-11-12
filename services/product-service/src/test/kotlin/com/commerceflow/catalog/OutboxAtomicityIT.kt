package com.commerceflow.catalog

import com.commerceflow.catalog.application.CreateProduct
import com.commerceflow.catalog.application.CreateProductCommand
import com.commerceflow.catalog.application.EventContext
import com.commerceflow.catalog.application.ProductEventPublisher
import com.commerceflow.catalog.domain.DuplicateSku
import com.commerceflow.catalog.domain.ProductEvent
import com.commerceflow.catalog.support.PostgresIntegrationTest
import com.commerceflow.events.product.ProductCreated
import io.confluent.kafka.serializers.KafkaAvroDeserializer
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.TestConfiguration
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Import
import org.springframework.context.annotation.Primary
import org.springframework.jdbc.core.simple.JdbcClient
import java.util.UUID

/**
 * Transactional outbox: the product rows and the outbox row are committed together, and a
 * failure anywhere in the use case leaves neither behind.
 */
@Import(OutboxAtomicityIT.FailureSwitch::class)
class OutboxAtomicityIT : PostgresIntegrationTest() {

    @Autowired lateinit var createProduct: CreateProduct
    @Autowired lateinit var jdbc: JdbcClient
    @Autowired lateinit var failure: FailureSwitch

    /** Wraps the real outbox publisher; can be told to fail AFTER the outbox row was written. */
    @TestConfiguration
    class FailureSwitch {
        @Volatile var failAfterPublish = false

        @Bean
        @Primary
        fun failingPublisher(real: ProductEventPublisher): ProductEventPublisher = object : ProductEventPublisher {
            override fun publish(events: List<ProductEvent>, context: EventContext) {
                real.publish(events, context)
                if (failAfterPublish) throw IllegalStateException("simulated failure after outbox write")
            }
        }
    }

    private fun sku() = "SKU-" + UUID.randomUUID().toString().substring(0, 8).uppercase()
    private fun command(vararg skus: String, correlationId: String = "corr-${UUID.randomUUID()}") =
        CreateProductCommand("Trail Shoe", null, null, skus.map { CreateProductCommand.SkuInput(it, "S") }, correlationId)

    private fun count(sql: String, vararg params: Pair<String, Any>): Int =
        params.fold(jdbc.sql(sql)) { s, (k, v) -> s.param(k, v) }.query(Int::class.java).single()

    @Test
    fun `commit writes product, SKUs and exactly one ProductCreated outbox row`() {
        failure.failAfterPublish = false
        val product = createProduct.handle(command(sku(), sku(), correlationId = "corr-commit"))
        val id = product.id.value

        assertThat(count("SELECT count(*) FROM product WHERE id = :id", "id" to id)).isEqualTo(1)
        assertThat(count("SELECT count(*) FROM product_sku WHERE product_id = :id", "id" to id)).isEqualTo(2)

        val row = jdbc.sql("SELECT id, aggregate_type, aggregate_id, type, topic, payload FROM outbox WHERE aggregate_id = :a")
            .param("a", id.toString())
            .query { rs, _ -> mapOf("id" to rs.getObject("id"), "aggregate_type" to rs.getString("aggregate_type"),
                "type" to rs.getString("type"), "topic" to rs.getString("topic"), "payload" to rs.getBytes("payload")) }
            .list().single()
        assertThat(row["aggregate_type"]).isEqualTo("product")
        assertThat(row["type"]).isEqualTo("ProductCreated")
        assertThat(row["topic"]).isEqualTo("cf.product.events.v1")

        // payload is Confluent-framed Avro that a consumer can decode with the registered schema
        val deserializer = KafkaAvroDeserializer().apply {
            configure(mapOf("schema.registry.url" to "mock://$REGISTRY_SCOPE", "specific.avro.reader" to true), false)
        }
        val event = deserializer.deserialize("cf.product.events.v1", row["payload"] as ByteArray) as ProductCreated
        assertThat(event.metadata.eventId).isEqualTo(row["id"])
        assertThat(event.metadata.aggregateId).isEqualTo(id.toString())
        assertThat(event.metadata.aggregateType).isEqualTo("product")
        assertThat(event.metadata.schemaVersion).isEqualTo(1)
        assertThat(event.metadata.correlationId).isEqualTo("corr-commit")
        assertThat(event.metadata.causationId).isNull()
        assertThat(event.metadata.producer).isEqualTo("product-service")
        assertThat(event.payload.productId).isEqualTo(id)
        assertThat(event.payload.skus.map { it.sku }).containsExactlyElementsOf(product.skus.map { it.code.value })
    }

    @Test
    fun `failure after the outbox write rolls back product and outbox together`() {
        val code = sku()
        failure.failAfterPublish = true
        try {
            assertThatThrownBy { createProduct.handle(command(code)) }.hasMessageContaining("simulated failure")
        } finally {
            failure.failAfterPublish = false
        }
        assertThat(count("SELECT count(*) FROM product_sku WHERE sku = :s", "s" to code)).isZero()
        assertThat(count("SELECT count(*) FROM outbox o WHERE NOT EXISTS (SELECT 1 FROM product p WHERE p.id::text = o.aggregate_id)")).isZero()
    }

    @Test
    fun `duplicate SKU rolls back the second product and writes no outbox row for it`() {
        val code = sku()
        createProduct.handle(command(code))
        val outboxBefore = count("SELECT count(*) FROM outbox")
        val productsBefore = count("SELECT count(*) FROM product")

        assertThatThrownBy { createProduct.handle(command(code)) }.isInstanceOf(DuplicateSku::class.java)

        assertThat(count("SELECT count(*) FROM outbox")).isEqualTo(outboxBefore)
        assertThat(count("SELECT count(*) FROM product")).isEqualTo(productsBefore)
    }
}
