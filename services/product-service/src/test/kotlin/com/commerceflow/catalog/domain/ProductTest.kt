package com.commerceflow.catalog.domain

import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.ValueSource
import java.time.Instant
import java.util.UUID

class ProductTest {
    private val now = Instant.parse("2026-11-12T10:00:00Z")
    private val id = ProductId(UUID.fromString("0190d1c4-6b8c-7c3e-9f5e-1a2b3c4d5e6f"))

    private fun sku(code: String, name: String = "Variant $code") = Sku(SkuCode(code), name)

    @Test
    fun `create makes a DRAFT product and records ProductCreated`() {
        val product = Product.create(id, "  Trail Shoe  ", "Light", null, listOf(sku("SHOE-42"), sku("SHOE-43")), now)

        assertThat(product.status).isEqualTo(ProductStatus.DRAFT)
        assertThat(product.name).isEqualTo("Trail Shoe")
        assertThat(product.pullEvents()).singleElement().isEqualTo(
            ProductEvent.Created(id, now, "Trail Shoe", null, ProductStatus.DRAFT, listOf(sku("SHOE-42"), sku("SHOE-43"))),
        )
    }

    @Test
    fun `events are pulled once`() {
        val product = Product.create(id, "Shoe", null, null, listOf(sku("SHOE-42")), now)
        product.pullEvents()
        assertThat(product.pullEvents()).isEmpty()
    }

    @Test
    fun `restore records no events`() {
        val product = Product.restore(id, "Shoe", null, null, ProductStatus.ACTIVE, listOf(sku("SHOE-42")), now)
        assertThat(product.pullEvents()).isEmpty()
    }

    @Test
    fun `a product needs at least one SKU`() {
        assertThatThrownBy { Product.create(id, "Shoe", null, null, emptyList(), now) }
            .isInstanceOf(InvalidProduct::class.java).hasMessageContaining("at least one SKU")
    }

    @Test
    fun `duplicate SKU codes in one product are rejected`() {
        assertThatThrownBy { Product.create(id, "Shoe", null, null, listOf(sku("SHOE-42"), sku("SHOE-42")), now) }
            .isInstanceOf(InvalidProduct::class.java).hasMessageContaining("SHOE-42")
    }

    @ParameterizedTest
    @ValueSource(strings = ["", "   "])
    fun `blank names are rejected`(name: String) {
        assertThatThrownBy { Product.create(id, name, null, null, listOf(sku("SHOE-42")), now) }
            .isInstanceOf(InvalidProduct::class.java)
    }

    @Test
    fun `names longer than 200 characters are rejected`() {
        assertThatThrownBy { Product.create(id, "x".repeat(201), null, null, listOf(sku("SHOE-42")), now) }
            .isInstanceOf(InvalidProduct::class.java)
    }

    @ParameterizedTest
    @ValueSource(strings = ["ab", "shoe-42", "-SHOE", "SH", "SHOE 42", "SHOE_42"])
    fun `invalid SKU codes are rejected`(code: String) {
        assertThatThrownBy { SkuCode(code) }.isInstanceOf(InvalidProduct::class.java)
    }

    @ParameterizedTest
    @ValueSource(strings = ["ABC", "SHOE-42", "A1-B2-C3"])
    fun `valid SKU codes are accepted`(code: String) {
        assertThat(SkuCode(code).value).isEqualTo(code)
    }
}
