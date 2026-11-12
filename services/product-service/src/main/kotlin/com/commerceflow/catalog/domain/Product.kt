package com.commerceflow.catalog.domain

import java.time.Instant
import java.util.UUID

@JvmInline
value class ProductId(val value: UUID)

@JvmInline
value class CategoryId(val value: UUID)

/** Stock-keeping unit code: upper-case letters, digits and dashes, 3..40 characters. */
@JvmInline
value class SkuCode(val value: String) {
    init {
        if (!PATTERN.matches(value)) throw InvalidProduct("SKU '$value' must match ${PATTERN.pattern}")
    }

    companion object {
        val PATTERN = Regex("^[A-Z0-9][A-Z0-9-]{2,39}$")
    }
}

data class Sku(val code: SkuCode, val name: String) {
    init {
        if (name.isBlank() || name.length > MAX_NAME) throw InvalidProduct("SKU name must be 1..$MAX_NAME characters")
    }

    companion object {
        const val MAX_NAME = 200
    }
}

enum class ProductStatus { DRAFT, ACTIVE }

/** Thrown when input violates a catalog invariant. */
class InvalidProduct(message: String) : RuntimeException(message)

sealed interface ProductEvent {
    val productId: ProductId
    val occurredAt: Instant

    data class Created(
        override val productId: ProductId,
        override val occurredAt: Instant,
        val name: String,
        val categoryId: CategoryId?,
        val status: ProductStatus,
        val skus: List<Sku>,
    ) : ProductEvent
}

/**
 * Product aggregate. A product is created as DRAFT with at least one SKU; SKU codes are
 * unique within the product (and globally, enforced by the repository).
 */
class Product private constructor(
    val id: ProductId,
    val name: String,
    val description: String?,
    val categoryId: CategoryId?,
    val status: ProductStatus,
    val skus: List<Sku>,
    val createdAt: Instant,
) {
    private val pending = mutableListOf<ProductEvent>()

    /** Domain events recorded since the last call; the caller publishes them through the outbox. */
    fun pullEvents(): List<ProductEvent> = pending.toList().also { pending.clear() }

    companion object {
        const val MAX_NAME = 200
        const val MAX_DESCRIPTION = 4000
        const val MAX_SKUS = 100

        fun create(
            id: ProductId,
            name: String,
            description: String?,
            categoryId: CategoryId?,
            skus: List<Sku>,
            now: Instant,
        ): Product {
            val trimmed = name.trim()
            if (trimmed.isEmpty() || trimmed.length > MAX_NAME) throw InvalidProduct("Product name must be 1..$MAX_NAME characters")
            if (description != null && description.length > MAX_DESCRIPTION) {
                throw InvalidProduct("Description must be at most $MAX_DESCRIPTION characters")
            }
            if (skus.isEmpty()) throw InvalidProduct("A product needs at least one SKU")
            if (skus.size > MAX_SKUS) throw InvalidProduct("A product can have at most $MAX_SKUS SKUs")
            val duplicates = skus.groupBy { it.code }.filterValues { it.size > 1 }.keys
            if (duplicates.isNotEmpty()) throw InvalidProduct("Duplicate SKU codes: ${duplicates.joinToString { it.value }}")

            return Product(id, trimmed, description, categoryId, ProductStatus.DRAFT, skus, now).also {
                it.pending += ProductEvent.Created(id, now, trimmed, categoryId, ProductStatus.DRAFT, skus)
            }
        }

        /** Rebuilds a stored product without recording events. */
        fun restore(
            id: ProductId,
            name: String,
            description: String?,
            categoryId: CategoryId?,
            status: ProductStatus,
            skus: List<Sku>,
            createdAt: Instant,
        ) = Product(id, name, description, categoryId, status, skus, createdAt)
    }
}

/** Repository port implemented in infrastructure. */
interface ProductRepository {
    /** @throws DuplicateSku if a SKU code already belongs to another product */
    fun add(product: Product)
    fun findById(id: ProductId): Product?
}

class DuplicateSku(val codes: List<String>) : RuntimeException("SKU already exists: ${codes.joinToString()}")
