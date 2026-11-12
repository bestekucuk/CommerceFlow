package com.commerceflow.catalog.infrastructure.config

import com.commerceflow.catalog.application.CreateProduct
import com.commerceflow.catalog.application.GetProduct
import com.commerceflow.catalog.application.ProductEventPublisher
import com.commerceflow.catalog.domain.ProductRepository
import com.commerceflow.catalog.infrastructure.outbox.OutboxProductEventPublisher
import com.commerceflow.catalog.infrastructure.persistence.JdbcProductRepository
import io.confluent.kafka.serializers.KafkaAvroSerializer
import org.springframework.beans.factory.annotation.Value
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.jdbc.core.simple.JdbcClient

/** Wires use cases to adapters. Domain and application classes carry no Spring stereotypes. */
@Configuration
class CatalogConfig {

    @Bean
    fun productRepository(jdbc: JdbcClient): ProductRepository = JdbcProductRepository(jdbc)

    /**
     * Serializes outbox payloads (Confluent wire format). The writer schema is PINNED to the
     * schema of the generated class: the serializer looks up that exact schema's id and never
     * writes with a different registered version (a later v2 with other fields would corrupt
     * positional writes). Schemas are registered by the pipeline, never by the service.
     * Generated classes carry "avro.java.string" properties that the registered contract does
     * not have; they are removed before the lookup (verified against the local registry).
     */
    @Bean
    fun avroSerializer(@Value("\${commerceflow.schema-registry.url}") registryUrl: String): KafkaAvroSerializer =
        KafkaAvroSerializer().apply {
            configure(
                mapOf(
                    "schema.registry.url" to registryUrl,
                    "auto.register.schemas" to false,
                    "use.latest.version" to false,
                    "avro.remove.java.properties" to true,
                    "value.subject.name.strategy" to "io.confluent.kafka.serializers.subject.TopicRecordNameStrategy",
                ),
                false,
            )
        }

    @Bean
    fun productEventPublisher(jdbc: JdbcClient, serializer: KafkaAvroSerializer): ProductEventPublisher =
        OutboxProductEventPublisher(jdbc, serializer)

    @Bean
    fun createProduct(products: ProductRepository, events: ProductEventPublisher) = CreateProduct(products, events)

    @Bean
    fun getProduct(products: ProductRepository) = GetProduct(products)
}
