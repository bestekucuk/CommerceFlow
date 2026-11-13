package com.commerceflow.pricing.presentation

import com.commerceflow.pricing.application.CreateQuote
import com.commerceflow.pricing.application.GetPrices
import com.commerceflow.pricing.application.GetQuote
import com.commerceflow.pricing.application.QuoteLineInput
import com.commerceflow.pricing.application.SetPrice
import com.commerceflow.pricing.application.SetPriceCommand
import com.commerceflow.pricing.domain.Money
import com.commerceflow.pricing.domain.Price
import com.commerceflow.pricing.domain.Quote
import com.commerceflow.pricing.domain.Total
import com.commerceflow.pricing.application.IfMatch
import org.slf4j.LoggerFactory
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.PutMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestHeader
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController
import java.net.URI
import java.time.Instant
import java.util.UUID

data class MoneyDto(val amountMinor: Long, val currency: String) {
    companion object {
        fun of(m: Money) = MoneyDto(m.amountMinor, m.currency)
        fun of(t: Total) = MoneyDto(t.amountMinor, t.currency)
    }
}

data class SetPriceRequest(val amountMinor: Long?, val currency: String?)

data class PriceResponse(val sku: String, val price: MoneyDto, val version: Int, val updatedAt: Instant) {
    companion object {
        fun of(p: Price) = PriceResponse(p.sku.value, MoneyDto.of(p.money), p.version, p.updatedAt)
    }
}

data class PriceList(val items: List<PriceResponse>)

data class CreateQuoteRequest(val lines: List<Line>?) {
    data class Line(val sku: String?, val quantity: Int?)
}

data class QuoteResponse(val id: UUID, val lines: List<Line>, val total: MoneyDto, val createdAt: Instant, val expiresAt: Instant, val expired: Boolean) {
    data class Line(val sku: String, val quantity: Int, val unitPrice: MoneyDto, val lineTotal: MoneyDto)

    companion object {
        fun of(q: Quote, now: Instant) = QuoteResponse(
            q.id,
            q.lines.map { Line(it.sku.value, it.quantity, MoneyDto.of(it.unitPrice), MoneyDto.of(it.lineTotal)) },
            MoneyDto.of(q.total), q.createdAt, q.expiresAt, q.isExpired(now),
        )
    }
}

/** Prices API (contracts/openapi/pricing-service.v1.yaml). Authentication arrives with CF-068. */
@RestController
@RequestMapping("/v1/prices")
class PriceController(private val setPrice: SetPrice, private val getPrices: GetPrices) {
    private val log = LoggerFactory.getLogger(javaClass)

    @GetMapping
    fun list(@RequestParam("sku") skus: List<String>): PriceList {
        if (skus.isEmpty() || skus.size > 100) throw InvalidRequest("between 1 and 100 sku parameters are required")
        return PriceList(getPrices.many(skus).map(PriceResponse::of))
    }

    @GetMapping("/{sku}")
    fun get(@PathVariable sku: String): ResponseEntity<PriceResponse> {
        val price = getPrices.one(sku) ?: throw NotFound("No price for $sku")
        return ResponseEntity.ok().eTag(etag(price.version)).body(PriceResponse.of(price))
    }

    @PutMapping("/{sku}")
    fun put(
        @PathVariable sku: String,
        @RequestHeader("If-Match", required = false) ifMatch: String?,
        @RequestBody body: SetPriceRequest,
    ): ResponseEntity<PriceResponse> {
        val result = setPrice.handle(
            SetPriceCommand(
                sku = sku,
                amountMinor = body.amountMinor ?: throw InvalidRequest("amountMinor is required"),
                currency = body.currency ?: throw InvalidRequest("currency is required"),
                ifMatch = ifMatch?.let(::parseIfMatch),
            ),
        )
        log.info("price set sku={} version={} created={}", sku, result.price.version, result.created)
        val builder = if (result.created) ResponseEntity.created(URI.create("/v1/prices/$sku")) else ResponseEntity.ok()
        return builder.eTag(etag(result.price.version)).body(PriceResponse.of(result.price))
    }

    private fun etag(version: Int) = "\"$version\""

    /** RFC 9110 If-Match: `*` or a list of strong ETags; weak or malformed tags never match. */
    private fun parseIfMatch(raw: String): IfMatch {
        if (raw.trim() == "*") return IfMatch.Any
        val versions = raw.split(',').map { it.trim() }
            .filter { it.startsWith('"') && it.endsWith('"') && it.length > 2 }
            .mapNotNull { it.trim('"').toIntOrNull() }.toSet()
        if (versions.isEmpty()) throw StaleEtag()
        return IfMatch.Versions(versions)
    }
}

/** Quotes API: freezes a basket's prices until expiresAt. */
@RestController
@RequestMapping("/v1/quotes")
class QuoteController(private val createQuote: CreateQuote, private val getQuote: GetQuote, private val clock: java.time.Clock) {
    private val log = LoggerFactory.getLogger(javaClass)

    @PostMapping
    fun create(@RequestBody body: CreateQuoteRequest): ResponseEntity<QuoteResponse> {
        val lines = body.lines ?: throw InvalidRequest("lines is required")
        val quote = createQuote.handle(
            lines.map {
                QuoteLineInput(
                    it.sku ?: throw InvalidRequest("lines[].sku is required"),
                    it.quantity ?: throw InvalidRequest("lines[].quantity is required"),
                )
            },
        )
        log.info("quote created quoteId={} lines={} total={} {}", quote.id, quote.lines.size, quote.total.amountMinor, quote.total.currency)
        return ResponseEntity.status(HttpStatus.CREATED).location(URI.create("/v1/quotes/${quote.id}")).body(QuoteResponse.of(quote, Instant.now(clock)))
    }

    @GetMapping("/{id}")
    fun get(@PathVariable id: UUID): QuoteResponse =
        getQuote.handle(id)?.let { QuoteResponse.of(it, Instant.now(clock)) } ?: throw NotFound("Quote $id not found")
}

class InvalidRequest(message: String) : RuntimeException(message)
class NotFound(message: String) : RuntimeException(message)
class StaleEtag : RuntimeException("If-Match does not match the current version")
