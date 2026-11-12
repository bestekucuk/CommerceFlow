package com.commerceflow.catalog

import com.commerceflow.catalog.support.PostgresIntegrationTest
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.web.client.TestRestTemplate
import org.springframework.http.HttpEntity
import org.springframework.http.HttpHeaders
import org.springframework.http.HttpStatus
import org.springframework.http.MediaType
import java.util.UUID

class ProductApiIT : PostgresIntegrationTest() {

    @Autowired
    lateinit var http: TestRestTemplate

    private fun post(body: String, correlationId: String? = null) = http.postForEntity(
        "/v1/products",
        HttpEntity(body, HttpHeaders().apply {
            contentType = MediaType.APPLICATION_JSON
            correlationId?.let { set("X-Correlation-Id", it) }
        }),
        Map::class.java,
    )

    private fun uniqueSku() = "SKU-" + UUID.randomUUID().toString().substring(0, 8).uppercase()

    @Test
    fun `POST creates a product, returns 201 with Location, and GET returns it`() {
        val sku = uniqueSku()
        val created = post("""{"name":"Trail Shoe","description":"Light","skus":[{"sku":"$sku","name":"Size 42"}]}""", "it-corr-1")

        assertThat(created.statusCode).isEqualTo(HttpStatus.CREATED)
        assertThat(created.headers.getFirst("X-Correlation-Id")).isEqualTo("it-corr-1")
        val id = created.body!!["id"] as String
        assertThat(created.headers.location.toString()).isEqualTo("/v1/products/$id")
        assertThat(created.body!!["status"]).isEqualTo("DRAFT")

        val fetched = http.getForEntity("/v1/products/$id", Map::class.java)
        assertThat(fetched.statusCode).isEqualTo(HttpStatus.OK)
        assertThat(fetched.body!!["name"]).isEqualTo("Trail Shoe")
        @Suppress("UNCHECKED_CAST")
        assertThat((fetched.body!!["skus"] as List<Map<String, String>>).single()["sku"]).isEqualTo(sku)
    }

    @Test
    fun `a correlation id is generated when the client sends none`() {
        val created = post("""{"name":"Shoe","skus":[{"sku":"${uniqueSku()}","name":"S"}]}""")
        assertThat(created.headers.getFirst("X-Correlation-Id")).isNotBlank()
    }

    @Test
    fun `missing fields return 400 problem details`() {
        val response = post("""{"name":"Shoe"}""")
        assertThat(response.statusCode).isEqualTo(HttpStatus.BAD_REQUEST)
        assertThat(response.headers.contentType.toString()).contains("application/problem+json")
        assertThat(response.body!!["type"]).isEqualTo("https://commerceflow.dev/problems/invalid-request")
    }

    @Test
    fun `business rule violations return 422`() {
        val response = post("""{"name":"Shoe","skus":[{"sku":"bad sku","name":"S"}]}""")
        assertThat(response.statusCode).isEqualTo(HttpStatus.UNPROCESSABLE_ENTITY)
        assertThat(response.body!!["type"]).isEqualTo("https://commerceflow.dev/problems/invalid-product")
    }

    @Test
    fun `a SKU used by another product returns 409`() {
        val sku = uniqueSku()
        assertThat(post("""{"name":"A","skus":[{"sku":"$sku","name":"S"}]}""").statusCode).isEqualTo(HttpStatus.CREATED)
        val second = post("""{"name":"B","skus":[{"sku":"$sku","name":"S"}]}""")
        assertThat(second.statusCode).isEqualTo(HttpStatus.CONFLICT)
        assertThat(second.body!!["type"]).isEqualTo("https://commerceflow.dev/problems/duplicate-sku")
    }

    @Test
    fun `unknown product returns 404`() {
        val response = http.getForEntity("/v1/products/${UUID.randomUUID()}", Map::class.java)
        assertThat(response.statusCode).isEqualTo(HttpStatus.NOT_FOUND)
    }
}
