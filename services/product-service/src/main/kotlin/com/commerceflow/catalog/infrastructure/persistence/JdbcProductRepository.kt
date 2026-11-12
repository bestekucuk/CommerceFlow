package com.commerceflow.catalog.infrastructure.persistence

import com.commerceflow.catalog.domain.CategoryId
import com.commerceflow.catalog.domain.DuplicateSku
import com.commerceflow.catalog.domain.Product
import com.commerceflow.catalog.domain.ProductId
import com.commerceflow.catalog.domain.ProductRepository
import com.commerceflow.catalog.domain.ProductStatus
import com.commerceflow.catalog.domain.Sku
import com.commerceflow.catalog.domain.SkuCode
import org.springframework.dao.DuplicateKeyException
import org.springframework.jdbc.core.simple.JdbcClient
import java.sql.Timestamp
import java.util.UUID

/** PostgreSQL repository. Joins the caller's transaction; never starts its own. */
class JdbcProductRepository(private val jdbc: JdbcClient) : ProductRepository {

    override fun add(product: Product) {
        jdbc.sql(
            """
            INSERT INTO product (id, name, description, category_id, status, created_at)
            VALUES (:id, :name, :description, :categoryId, :status, :createdAt)
            """.trimIndent(),
        )
            .param("id", product.id.value)
            .param("name", product.name)
            .param("description", product.description)
            .param("categoryId", product.categoryId?.value)
            .param("status", product.status.name)
            .param("createdAt", Timestamp.from(product.createdAt))
            .update()
        try {
            product.skus.forEachIndexed { position, sku ->
                jdbc.sql("INSERT INTO product_sku (sku, product_id, position, name) VALUES (:sku, :productId, :position, :name)")
                    .param("sku", sku.code.value)
                    .param("productId", product.id.value)
                    .param("position", position)
                    .param("name", sku.name)
                    .update()
            }
        } catch (e: DuplicateKeyException) {
            throw DuplicateSku(product.skus.map { it.code.value })
        }
    }

    override fun findById(id: ProductId): Product? {
        val row = jdbc.sql("SELECT name, description, category_id, status, created_at FROM product WHERE id = :id")
            .param("id", id.value)
            .query { rs, _ ->
                listOf(
                    rs.getString("name"), rs.getString("description"), rs.getObject("category_id", UUID::class.java),
                    rs.getString("status"), rs.getTimestamp("created_at").toInstant(),
                )
            }
            .optional()
            .orElse(null) ?: return null
        val skus = jdbc.sql("SELECT sku, name FROM product_sku WHERE product_id = :id ORDER BY position")
            .param("id", id.value)
            .query { rs, _ -> Sku(SkuCode(rs.getString("sku")), rs.getString("name")) }
            .list()
        return Product.restore(
            id = id,
            name = row[0] as String,
            description = row[1] as String?,
            categoryId = (row[2] as UUID?)?.let(::CategoryId),
            status = ProductStatus.valueOf(row[3] as String),
            skus = skus,
            createdAt = row[4] as java.time.Instant,
        )
    }
}
