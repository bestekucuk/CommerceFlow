package com.commerceflow.catalog.presentation

import com.commerceflow.catalog.application.CreateProduct
import com.commerceflow.catalog.application.CreateProductCommand
import com.commerceflow.catalog.application.GetProduct
import com.commerceflow.catalog.domain.Product
import jakarta.servlet.http.HttpServletRequest
import org.slf4j.LoggerFactory
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController
import java.net.URI
import java.time.Instant
import java.util.UUID

data class CreateProductRequest(
    val name: String?,
    val description: String? = null,
    val categoryId: UUID? = null,
    val skus: List<SkuRequest>?,
) {
    data class SkuRequest(val sku: String?, val name: String?)
}

data class ProductResponse(
    val id: UUID,
    val name: String,
    val description: String?,
    val categoryId: UUID?,
    val status: String,
    val skus: List<SkuResponse>,
    val createdAt: Instant,
) {
    data class SkuResponse(val sku: String, val name: String)

    companion object {
        fun of(p: Product) = ProductResponse(
            id = p.id.value, name = p.name, description = p.description, categoryId = p.categoryId?.value,
            status = p.status.name, skus = p.skus.map { SkuResponse(it.code.value, it.name) }, createdAt = p.createdAt,
        )
    }
}

/** Catalog API (contracts/openapi/product-service.v1.yaml). Authentication arrives with CF-068. */
@RestController
@RequestMapping("/v1/products")
class ProductController(private val createProduct: CreateProduct, private val getProduct: GetProduct) {
    private val log = LoggerFactory.getLogger(javaClass)

    @PostMapping
    fun create(@RequestBody body: CreateProductRequest, request: HttpServletRequest): ResponseEntity<ProductResponse> {
        val skus = body.skus ?: throw InvalidRequest("skus is required")
        val product = createProduct.handle(
            CreateProductCommand(
                name = body.name ?: throw InvalidRequest("name is required"),
                description = body.description,
                categoryId = body.categoryId,
                skus = skus.map {
                    CreateProductCommand.SkuInput(
                        it.sku ?: throw InvalidRequest("skus[].sku is required"),
                        it.name ?: throw InvalidRequest("skus[].name is required"),
                    )
                },
                correlationId = CorrelationIdFilter.current(request),
            ),
        )
        log.info("product created productId={} skus={}", product.id.value, product.skus.size)
        return ResponseEntity.created(URI.create("/v1/products/${product.id.value}")).body(ProductResponse.of(product))
    }

    @GetMapping("/{id}")
    fun get(@PathVariable id: UUID): ResponseEntity<ProductResponse> =
        getProduct.handle(id)?.let { ResponseEntity.ok(ProductResponse.of(it)) } ?: throw ProductNotFound(id)
}

class InvalidRequest(message: String) : RuntimeException(message)
class ProductNotFound(val id: UUID) : RuntimeException("Product $id not found")
