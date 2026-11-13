package com.commerceflow.pricing.application

import com.commerceflow.pricing.domain.Money
import com.commerceflow.pricing.domain.Price
import com.commerceflow.pricing.domain.PriceRepository
import com.commerceflow.pricing.domain.SkuCode
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test
import java.time.Clock
import java.time.Instant
import java.time.ZoneOffset

class SetPriceTest {
    private val clock = Clock.fixed(Instant.parse("2026-11-12T10:00:00Z"), ZoneOffset.UTC)
    private val repo = InMemoryPrices()
    private val setPrice = SetPrice(repo, clock)

    @Test
    fun `first price is created with version 1 without a precondition`() {
        val r = setPrice.handle(SetPriceCommand("SHOE-42", 129_900, "TRY", null))
        assertThat(r.created).isTrue()
        assertThat(r.price.version).isEqualTo(1)
    }

    @Test
    fun `updating needs the current version and increments it`() {
        setPrice.handle(SetPriceCommand("SHOE-42", 100, "TRY", null))

        assertThatThrownBy { setPrice.handle(SetPriceCommand("SHOE-42", 200, "TRY", null)) }
            .isInstanceOf(PreconditionRequired::class.java)
        val r = setPrice.handle(SetPriceCommand("SHOE-42", 200, "TRY", IfMatch.Versions(setOf(1))))
        assertThat(r.created).isFalse()
        assertThat(r.price.version).isEqualTo(2)
        assertThat(repo.find(SkuCode("SHOE-42"))!!.money).isEqualTo(Money(200, "TRY"))
    }

    @Test
    fun `a stale version is rejected and nothing changes`() {
        setPrice.handle(SetPriceCommand("SHOE-42", 100, "TRY", null))
        setPrice.handle(SetPriceCommand("SHOE-42", 200, "TRY", IfMatch.Versions(setOf(1))))

        assertThatThrownBy { setPrice.handle(SetPriceCommand("SHOE-42", 300, "TRY", IfMatch.Versions(setOf(1)))) }
            .isInstanceOfSatisfying(PriceVersionConflict::class.java) { assertThat(it.currentVersion).isEqualTo(2) }
        assertThat(repo.find(SkuCode("SHOE-42"))!!.money.amountMinor).isEqualTo(200)
    }

    @Test
    fun `If-Match on a SKU without a price is a conflict`() {
        assertThatThrownBy { setPrice.handle(SetPriceCommand("SHOE-42", 100, "TRY", IfMatch.Versions(setOf(3)))) }
            .isInstanceOf(PriceVersionConflict::class.java)
    }

    private class InMemoryPrices : PriceRepository {
        val rows = mutableMapOf<SkuCode, Price>()
        override fun find(sku: SkuCode) = rows[sku]
        override fun findAll(skus: Collection<SkuCode>) = skus.mapNotNull { rows[it] }
        override fun insert(price: Price) = rows.putIfAbsent(price.sku, price) == null
        override fun update(price: Price, expectedVersion: Int): Boolean {
            if (rows[price.sku]?.version != expectedVersion) return false
            rows[price.sku] = price
            return true
        }
    }
}
