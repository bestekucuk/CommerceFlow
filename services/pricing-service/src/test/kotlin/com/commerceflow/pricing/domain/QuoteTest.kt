package com.commerceflow.pricing.domain

import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test
import java.time.Duration
import java.time.Instant

class QuoteTest {
    private val now = Instant.parse("2026-11-12T10:00:00Z")
    private val ttl = Duration.ofMinutes(15)
    private fun price(sku: String, minor: Long, currency: String = "TRY") =
        SkuCode(sku) to Price(SkuCode(sku), Money(minor, currency), 1, now)

    @Test
    fun `totals are computed in minor units per line and overall`() {
        val prices = mapOf(price("SHOE-42", 129_900), price("SOCK-01", 4_950))
        val q = Quote.create(listOf(SkuCode("SHOE-42") to 2, SkuCode("SOCK-01") to 3), prices, now, ttl)

        assertThat(q.lines.map { it.lineTotal.amountMinor }).containsExactly(259_800, 14_850)
        assertThat(q.total).isEqualTo(Total(274_650, "TRY"))
        assertThat(q.expiresAt).isEqualTo(now.plus(ttl))
        assertThat(q.isExpired(now.plus(ttl).minusMillis(1))).isFalse()
        assertThat(q.isExpired(now.plus(ttl))).isTrue()
    }

    @Test
    fun `unpriced SKUs are reported all at once`() {
        assertThatThrownBy {
            Quote.create(listOf(SkuCode("SHOE-42") to 1, SkuCode("NOPE-1") to 1, SkuCode("NOPE-2") to 1), mapOf(price("SHOE-42", 1)), now, ttl)
        }.isInstanceOfSatisfying(UnpricedSkus::class.java) { assertThat(it.skus).containsExactly("NOPE-1", "NOPE-2") }
    }

    @Test
    fun `a basket cannot mix currencies`() {
        assertThatThrownBy {
            Quote.create(listOf(SkuCode("SHOE-42") to 1, SkuCode("SOCK-01") to 1), mapOf(price("SHOE-42", 1), price("SOCK-01", 1, "EUR")), now, ttl)
        }.isInstanceOf(MixedCurrencies::class.java)
    }

    @Test
    fun `lines are validated`() {
        val prices = mapOf(price("SHOE-42", 1))
        assertThatThrownBy { Quote.create(emptyList(), prices, now, ttl) }.isInstanceOf(InvalidQuote::class.java)
        assertThatThrownBy { Quote.create(listOf(SkuCode("SHOE-42") to 0), prices, now, ttl) }.isInstanceOf(InvalidQuote::class.java)
        assertThatThrownBy { Quote.create(listOf(SkuCode("SHOE-42") to 100), prices, now, ttl) }.isInstanceOf(InvalidQuote::class.java)
        assertThatThrownBy { Quote.create(listOf(SkuCode("SHOE-42") to 1, SkuCode("SHOE-42") to 2), prices, now, ttl) }.isInstanceOf(InvalidQuote::class.java)
    }

    @Test
    fun `money and sku reject invalid values`() {
        assertThatThrownBy { Money(-1, "TRY") }.isInstanceOf(InvalidPrice::class.java)
        assertThatThrownBy { Money(1, "try") }.isInstanceOf(InvalidPrice::class.java)
        assertThatThrownBy { SkuCode("bad sku") }.isInstanceOf(InvalidPrice::class.java)
        assertThatThrownBy { Money(Money.MAX_AMOUNT_MINOR + 1, "TRY") }.isInstanceOf(InvalidPrice::class.java)
    }
}
