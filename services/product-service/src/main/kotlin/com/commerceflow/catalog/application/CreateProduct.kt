package com.commerceflow.catalog.application

import com.commerceflow.catalog.domain.CategoryId
import com.commerceflow.catalog.domain.Product
import com.commerceflow.catalog.domain.ProductEvent
import com.commerceflow.catalog.domain.ProductId
import com.commerceflow.catalog.domain.ProductRepository
import com.commerceflow.catalog.domain.Sku
import com.commerceflow.catalog.domain.SkuCode
import org.springframework.transaction.annotation.Transactional
import java.time.Clock
import java.util.UUID

data class CreateProductCommand(
    val name: String,
    val description: String?,
    val categoryId: UUID?,
    val skus: List<SkuInput>,
    val correlationId: String,
) {
    data class SkuInput(val sku: String, val name: String)
}

/** Request-scoped context carried into published events. */
data class EventContext(val correlationId: String, val causationId: String? = null)

/** Output port: records domain events for publication (implemented by the outbox writer). */
interface ProductEventPublisher {
    fun publish(events: List<ProductEvent>, context: EventContext)
}

/**
 * Creates a product. The product rows and its outbox rows are written in ONE local
 * transaction: either both are committed or neither is (ADR-0006).
 */
open class CreateProduct(
    private val products: ProductRepository,
    private val events: ProductEventPublisher,
    private val clock: Clock = Clock.systemUTC(),
    private val ids: () -> UUID = UUID::randomUUID,
) {
    @Transactional
    open fun handle(command: CreateProductCommand): Product {
        val product = Product.create(
            id = ProductId(ids()),
            name = command.name,
            description = command.description,
            categoryId = command.categoryId?.let(::CategoryId),
            skus = command.skus.map { Sku(SkuCode(it.sku.trim()), it.name.trim()) },
            now = clock.instant(),
        )
        products.add(product)
        events.publish(product.pullEvents(), EventContext(command.correlationId))
        return product
    }
}

open class GetProduct(private val products: ProductRepository) {
    @Transactional(readOnly = true)
    open fun handle(id: UUID): Product? = products.findById(ProductId(id))
}
