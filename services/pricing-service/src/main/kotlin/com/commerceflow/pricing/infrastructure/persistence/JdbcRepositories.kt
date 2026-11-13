package com.commerceflow.pricing.infrastructure.persistence

import com.commerceflow.pricing.domain.Money
import com.commerceflow.pricing.domain.Price
import com.commerceflow.pricing.domain.PriceRepository
import com.commerceflow.pricing.domain.Quote
import com.commerceflow.pricing.domain.QuoteLine
import com.commerceflow.pricing.domain.QuoteRepository
import com.commerceflow.pricing.domain.SkuCode
import com.commerceflow.pricing.domain.Total
import org.springframework.jdbc.core.simple.JdbcClient
import java.sql.ResultSet
import java.sql.Timestamp
import java.util.UUID

class JdbcPriceRepository(private val jdbc: JdbcClient) : PriceRepository {

    override fun find(sku: SkuCode): Price? =
        jdbc.sql("SELECT sku, amount_minor, currency, version, updated_at FROM price WHERE sku = :sku")
            .param("sku", sku.value)
            .query { rs, _ -> rs.toPrice() }
            .optional().orElse(null)

    override fun findAll(skus: Collection<SkuCode>): List<Price> {
        if (skus.isEmpty()) return emptyList()
        return jdbc.sql("SELECT sku, amount_minor, currency, version, updated_at FROM price WHERE sku IN (:skus)")
            .param("skus", skus.map { it.value })
            .query { rs, _ -> rs.toPrice() }
            .list()
    }

    override fun insert(price: Price): Boolean =
        jdbc.sql(
            """
            INSERT INTO price (sku, amount_minor, currency, version, updated_at)
            VALUES (:sku, :amount, :currency, :version, :updatedAt)
            ON CONFLICT (sku) DO NOTHING
            """.trimIndent(),
        )
            .param("sku", price.sku.value).param("amount", price.money.amountMinor)
            .param("currency", price.money.currency).param("version", price.version)
            .param("updatedAt", Timestamp.from(price.updatedAt))
            .update() == 1

    override fun update(price: Price, expectedVersion: Int): Boolean =
        jdbc.sql(
            """
            UPDATE price SET amount_minor = :amount, currency = :currency, version = :version, updated_at = :updatedAt
            WHERE sku = :sku AND version = :expected
            """.trimIndent(),
        )
            .param("sku", price.sku.value).param("amount", price.money.amountMinor)
            .param("currency", price.money.currency).param("version", price.version)
            .param("updatedAt", Timestamp.from(price.updatedAt)).param("expected", expectedVersion)
            .update() == 1

    private fun ResultSet.toPrice() = Price(
        sku = SkuCode(getString("sku")),
        money = Money(getLong("amount_minor"), getString("currency").trim()),
        version = getInt("version"),
        updatedAt = getTimestamp("updated_at").toInstant(),
    )
}

class JdbcQuoteRepository(private val jdbc: JdbcClient) : QuoteRepository {

    override fun save(quote: Quote) {
        jdbc.sql(
            """
            INSERT INTO quote (id, currency, total_minor, created_at, expires_at)
            VALUES (:id, :currency, :total, :createdAt, :expiresAt)
            """.trimIndent(),
        )
            .param("id", quote.id).param("currency", quote.total.currency).param("total", quote.total.amountMinor)
            .param("createdAt", Timestamp.from(quote.createdAt)).param("expiresAt", Timestamp.from(quote.expiresAt))
            .update()
        quote.lines.forEachIndexed { i, line ->
            jdbc.sql(
                """
                INSERT INTO quote_line (quote_id, line_no, sku, quantity, unit_price_minor)
                VALUES (:quoteId, :lineNo, :sku, :quantity, :unitPrice)
                """.trimIndent(),
            )
                .param("quoteId", quote.id).param("lineNo", i + 1).param("sku", line.sku.value)
                .param("quantity", line.quantity).param("unitPrice", line.unitPrice.amountMinor)
                .update()
        }
    }

    override fun find(id: UUID): Quote? {
        data class Head(val currency: String, val total: Long, val created: Timestamp, val expires: Timestamp)
        val head = jdbc.sql("SELECT currency, total_minor, created_at, expires_at FROM quote WHERE id = :id")
            .param("id", id)
            .query { rs, _ -> Head(rs.getString("currency").trim(), rs.getLong("total_minor"), rs.getTimestamp("created_at"), rs.getTimestamp("expires_at")) }
            .optional().orElse(null) ?: return null
        val lines = jdbc.sql("SELECT sku, quantity, unit_price_minor FROM quote_line WHERE quote_id = :id ORDER BY line_no")
            .param("id", id)
            .query { rs, _ -> QuoteLine(SkuCode(rs.getString("sku")), rs.getInt("quantity"), Money(rs.getLong("unit_price_minor"), head.currency)) }
            .list()
        return Quote(id, lines, Total(head.total, head.currency), head.created.toInstant(), head.expires.toInstant())
    }
}
