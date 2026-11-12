package com.commerceflow.catalog.application

import com.commerceflow.catalog.domain.InvalidProduct
import com.commerceflow.catalog.domain.Product
import com.commerceflow.catalog.domain.ProductEvent
import com.commerceflow.catalog.domain.ProductId
import com.commerceflow.catalog.domain.ProductRepository
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test
import java.time.Clock
import java.time.Instant
import java.time.ZoneOffset
import java.util.UUID

class CreateProductTest {
    private val fixedId = UUID.fromString("0190d1c4-6b8c-7c3e-9f5e-1a2b3c4d5e6f")
    private val clock = Clock.fixed(Instant.parse("2026-11-12T10:00:00Z"), ZoneOffset.UTC)

    private class InMemoryProducts : ProductRepository {
        val saved = mutableMapOf<ProductId, Product>()
        override fun add(product: Product) { saved[product.id] = product }
        override fun findById(id: ProductId) = saved[id]
    }

    private class RecordingPublisher : ProductEventPublisher {
        val published = mutableListOf<Pair<ProductEvent, EventContext>>()
        override fun publish(events: List<ProductEvent>, context: EventContext) { events.forEach { published += it to context } }
    }

    private val products = InMemoryProducts()
    private val publisher = RecordingPublisher()
    private val useCase = CreateProduct(products, publisher, clock) { fixedId }

    private fun command(vararg skus: String) = CreateProductCommand(
        name = "Trail Shoe", description = null, categoryId = null,
        skus = skus.map { CreateProductCommand.SkuInput(it, "Variant $it") }, correlationId = "corr-1",
    )

    @Test
    fun `saves the product and publishes ProductCreated with the correlation id`() {
        val product = useCase.handle(command("SHOE-42"))

        assertThat(products.saved).containsKey(ProductId(fixedId))
        assertThat(publisher.published).singleElement().satisfies({ (event, context) ->
            assertThat(event).isInstanceOf(ProductEvent.Created::class.java)
            assertThat(event.productId).isEqualTo(product.id)
            assertThat(event.occurredAt).isEqualTo(clock.instant())
            assertThat(context).isEqualTo(EventContext("corr-1"))
        })
    }

    @Test
    fun `invalid input saves and publishes nothing`() {
        assertThatThrownBy { useCase.handle(command()) }.isInstanceOf(InvalidProduct::class.java)
        assertThat(products.saved).isEmpty()
        assertThat(publisher.published).isEmpty()
    }

    @Test
    fun `SKU codes and names are trimmed before validation`() {
        val product = useCase.handle(command(" SHOE-42 "))
        assertThat(product.skus.single().code.value).isEqualTo("SHOE-42")
    }
}
