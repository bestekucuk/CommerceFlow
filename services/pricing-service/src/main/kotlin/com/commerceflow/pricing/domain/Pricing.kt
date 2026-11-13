package com.commerceflow.pricing.domain

import java.time.Duration
import java.time.Instant
import java.util.UUID

/** A pricing rule was violated (maps to 400/422 in the API). */
open class PricingRuleViolation(message: String) : RuntimeException(message)

class InvalidPrice(message: String) : PricingRuleViolation(message)

@JvmInline
value class SkuCode(val value: String) {
    init {
        if (!PATTERN.matches(value)) throw InvalidPrice("SKU '$value' must match ${PATTERN.pattern}")
    }

    override fun toString() = value

    companion object {
        val PATTERN = Regex("^[A-Z0-9][A-Z0-9-]{2,39}$")
    }
}

/** Money in minor units. Never a floating-point number. */
data class Money(val amountMinor: Long, val currency: String) {
    init {
        if (amountMinor < 0) throw InvalidPrice("amount must not be negative")
        if (amountMinor > MAX_AMOUNT_MINOR) throw InvalidPrice("amount must not exceed $MAX_AMOUNT_MINOR minor units")
        if (!CURRENCY.matches(currency)) throw InvalidPrice("currency must be an ISO 4217 code like TRY")
    }

    /** Sums and line totals are not prices, so they are not capped by MAX_AMOUNT_MINOR. */
    fun plus(other: Money): Total {
        require(currency == other.currency) { "currency mismatch" }
        return Total(Math.addExact(amountMinor, other.amountMinor), currency)
    }

    operator fun times(quantity: Int): Total = Total(Math.multiplyExact(amountMinor, quantity.toLong()), currency)

    companion object {
        /** 10^13 minor units: with at most 50 lines of 99 items a quote total stays far below Long.MAX_VALUE. */
        const val MAX_AMOUNT_MINOR = 10_000_000_000_000L
        private val CURRENCY = Regex("^[A-Z]{3}$")
    }
}

/** An amount derived from prices (line total, quote total); same rules as Money without the price cap. */
data class Total(val amountMinor: Long, val currency: String) {
    init {
        require(amountMinor >= 0) { "total must not be negative" }
    }

    operator fun plus(other: Total): Total {
        require(currency == other.currency) { "currency mismatch" }
        return Total(Math.addExact(amountMinor, other.amountMinor), currency)
    }
}

/** The current price of one SKU. `version` drives optimistic concurrency (ETag). */
data class Price(val sku: SkuCode, val money: Money, val version: Int, val updatedAt: Instant)

/** Writes are conditional on the version the caller saw. */
interface PriceRepository {
    fun find(sku: SkuCode): Price?
    fun findAll(skus: Collection<SkuCode>): List<Price>

    /** Inserts a new price; false if the SKU already has one. */
    fun insert(price: Price): Boolean

    /** Updates only if the stored version equals [expectedVersion]; false otherwise. */
    fun update(price: Price, expectedVersion: Int): Boolean
}

data class QuoteLine(val sku: SkuCode, val quantity: Int, val unitPrice: Money) {
    val lineTotal: Total get() = unitPrice * quantity
}

class UnpricedSkus(val skus: List<String>) : PricingRuleViolation("No price for: ${skus.joinToString()}")
class MixedCurrencies(val currencies: Set<String>) : PricingRuleViolation("Basket mixes currencies: ${currencies.sorted().joinToString()}")
class InvalidQuote(message: String) : PricingRuleViolation(message)

/**
 * A frozen price calculation for a basket. Immutable once created; order-service accepts an
 * order only against an unexpired quote (ADR-0012).
 */
data class Quote(
    val id: UUID,
    val lines: List<QuoteLine>,
    val total: Total,
    val createdAt: Instant,
    val expiresAt: Instant,
) {
    fun isExpired(now: Instant) = !now.isBefore(expiresAt)

    companion object {
        const val MAX_LINES = 50
        const val MAX_QUANTITY = 99

        /** Shape checks that need no prices; run before touching the database. */
        fun validateRequest(requested: List<Pair<SkuCode, Int>>) {
            if (requested.isEmpty()) throw InvalidQuote("a quote needs at least one line")
            if (requested.size > MAX_LINES) throw InvalidQuote("at most $MAX_LINES lines")
            if (requested.map { it.first }.toSet().size != requested.size) throw InvalidQuote("each SKU may appear only once")
            requested.forEach { (sku, qty) ->
                if (qty !in 1..MAX_QUANTITY) throw InvalidQuote("quantity for $sku must be 1..$MAX_QUANTITY")
            }
        }

        fun create(requested: List<Pair<SkuCode, Int>>, prices: Map<SkuCode, Price>, now: Instant, ttl: Duration, id: UUID = UUID.randomUUID()): Quote {
            validateRequest(requested)
            val missing = requested.map { it.first }.filter { it !in prices }
            if (missing.isNotEmpty()) throw UnpricedSkus(missing.map { it.value })
            val lines = requested.map { (sku, qty) -> QuoteLine(sku, qty, prices.getValue(sku).money) }
            val currencies = lines.map { it.unitPrice.currency }.toSet()
            if (currencies.size > 1) throw MixedCurrencies(currencies)
            val total = lines.map { it.lineTotal }.reduce(Total::plus)
            return Quote(id, lines, total, now, now.plus(ttl))
        }
    }
}

interface QuoteRepository {
    fun save(quote: Quote)
    fun find(id: UUID): Quote?
}
