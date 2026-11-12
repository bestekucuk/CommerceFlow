package com.commerceflow.catalog.infrastructure.outbox

import com.commerceflow.catalog.application.EventContext
import com.commerceflow.catalog.application.ProductEventPublisher
import com.commerceflow.catalog.domain.ProductEvent
import com.commerceflow.events.common.EventMetadata
import com.commerceflow.events.product.ProductCreated
import com.commerceflow.events.product.ProductCreatedPayload
import com.commerceflow.events.product.ProductSku
import com.commerceflow.events.product.ProductStatus
import io.confluent.kafka.serializers.KafkaAvroSerializer
import io.opentelemetry.api.trace.Span
import org.apache.avro.specific.SpecificRecord
import org.springframework.jdbc.core.simple.JdbcClient
import java.sql.Timestamp
import java.util.UUID

/**
 * Writes product events to the transactional outbox (docs/event-catalog/outbox-design.md).
 * Runs inside the use case's transaction; Debezium relays the rows to Kafka.
 */
class OutboxProductEventPublisher(
    private val jdbc: JdbcClient,
    private val serializer: KafkaAvroSerializer,
    private val ids: () -> UUID = UUID::randomUUID,
) : ProductEventPublisher {

    override fun publish(events: List<ProductEvent>, context: EventContext) {
        val traceParent = currentTraceParent()
        events.forEach { event ->
            val eventId = ids()
            val record: SpecificRecord = when (event) {
                is ProductEvent.Created -> toContract(event, eventId, context)
            }
            jdbc.sql(
                """
                INSERT INTO outbox (id, aggregate_type, aggregate_id, type, topic, payload, occurred_at, trace_parent)
                VALUES (:id, :aggregateType, :aggregateId, :type, :topic, :payload, :occurredAt, :traceParent)
                """.trimIndent(),
            )
                .param("id", eventId)
                .param("aggregateType", AGGREGATE_TYPE)
                .param("aggregateId", event.productId.value.toString())
                .param("type", record.schema.name)
                .param("topic", TOPIC)
                .param("payload", serializer.serialize(TOPIC, record))
                .param("occurredAt", Timestamp.from(event.occurredAt))
                .param("traceParent", traceParent)
                .update()
        }
    }

    private fun toContract(event: ProductEvent.Created, eventId: UUID, context: EventContext): ProductCreated =
        ProductCreated.newBuilder()
            .setMetadata(
                EventMetadata.newBuilder()
                    .setEventId(eventId)
                    .setEventType("ProductCreated")
                    .setAggregateType(AGGREGATE_TYPE)
                    .setAggregateId(event.productId.value.toString())
                    .setOccurredAt(event.occurredAt)
                    .setSchemaVersion(1)
                    .setCorrelationId(context.correlationId)
                    .setCausationId(context.causationId)
                    .setProducer(PRODUCER)
                    .build(),
            )
            .setPayload(
                ProductCreatedPayload.newBuilder()
                    .setProductId(event.productId.value)
                    .setName(event.name)
                    .setCategoryId(event.categoryId?.value)
                    .setStatus(ProductStatus.valueOf(event.status.name))
                    .setSkus(event.skus.map { ProductSku.newBuilder().setSku(it.code.value).setName(it.name).build() })
                    .build(),
            )
            .build()

    companion object {
        const val TOPIC = "cf.product.events.v1"
        const val AGGREGATE_TYPE = "product"
        const val PRODUCER = "product-service"

        /** W3C traceparent of the current span, or null when no trace is active. */
        fun currentTraceParent(): String? {
            val ctx = Span.current().spanContext
            if (!ctx.isValid) return null
            val flags = if (ctx.isSampled) "01" else "00"
            return "00-${ctx.traceId}-${ctx.spanId}-$flags"
        }
    }
}
