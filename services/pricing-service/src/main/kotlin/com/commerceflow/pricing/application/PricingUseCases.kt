package com.commerceflow.pricing.application

import com.commerceflow.pricing.domain.Money
import com.commerceflow.pricing.domain.Price
import com.commerceflow.pricing.domain.PriceRepository
import com.commerceflow.pricing.domain.Quote
import com.commerceflow.pricing.domain.QuoteRepository
import com.commerceflow.pricing.domain.SkuCode
import org.springframework.transaction.annotation.Transactional
import java.time.Clock
import java.time.Duration
import java.time.Instant
import java.util.UUID

/** Updating an existing price needs the version the caller saw (If-Match). */
class PreconditionRequired : RuntimeException("If-Match is required to update an existing price")

/** Another update won; the caller must re-read and retry. */
class PriceVersionConflict(val currentVersion: Int?) : RuntimeException("price was changed by someone else")

/** Parsed If-Match: `*` (any existing price) or a list of strong ETag versions. */
sealed interface IfMatch {
    data object Any : IfMatch
    data class Versions(val versions: Set<Int>) : IfMatch

    fun matches(version: Int) = this == Any || (this is Versions && version in versions)
}

data class SetPriceCommand(val sku: String, val amountMinor: Long, val currency: String, val ifMatch: IfMatch?)
data class SetPriceResult(val price: Price, val created: Boolean)

/** Creates or updates the price of one SKU with optimistic concurrency. */
open class SetPrice(private val prices: PriceRepository, private val clock: Clock) {

    @Transactional
    open fun handle(cmd: SetPriceCommand): SetPriceResult {
        val sku = SkuCode(cmd.sku)
        val money = Money(cmd.amountMinor, cmd.currency)
        val now = Instant.now(clock)
        val current = prices.find(sku)
        if (current == null) {
            if (cmd.ifMatch != null) throw PriceVersionConflict(null) // RFC 9110: If-Match fails when nothing exists
            val created = Price(sku, money, 1, now)
            if (!prices.insert(created)) throw PriceVersionConflict(prices.find(sku)?.version)
            return SetPriceResult(created, true)
        }
        val ifMatch = cmd.ifMatch ?: throw PreconditionRequired()
        if (!ifMatch.matches(current.version)) throw PriceVersionConflict(current.version)
        val updated = Price(sku, money, current.version + 1, now)
        if (!prices.update(updated, current.version)) throw PriceVersionConflict(prices.find(sku)?.version)
        return SetPriceResult(updated, false)
    }
}

class GetPrices(private val prices: PriceRepository) {
    fun one(sku: String): Price? = prices.find(SkuCode(sku))
    fun many(skus: List<String>): List<Price> = prices.findAll(skus.map(::SkuCode).distinct())
}

data class QuoteLineInput(val sku: String, val quantity: Int)

/** Prices a basket from the current prices and stores the result. */
open class CreateQuote(
    private val prices: PriceRepository,
    private val quotes: QuoteRepository,
    private val clock: Clock,
    private val ttl: Duration,
) {
    @Transactional
    open fun handle(lines: List<QuoteLineInput>): Quote {
        if (lines.size > Quote.MAX_LINES) throw com.commerceflow.pricing.domain.InvalidQuote("at most ${Quote.MAX_LINES} lines")
        val requested = lines.map { SkuCode(it.sku) to it.quantity }
        Quote.validateRequest(requested) // before any database work
        val found = prices.findAll(requested.map { it.first }.distinct()).associateBy { it.sku }
        val quote = Quote.create(requested, found, Instant.now(clock), ttl)
        quotes.save(quote)
        return quote
    }
}

class GetQuote(private val quotes: QuoteRepository) {
    fun handle(id: UUID): Quote? = quotes.find(id)
}
