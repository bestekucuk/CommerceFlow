package com.commerceflow.pricing

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Tag
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.test.web.client.TestRestTemplate
import org.springframework.boot.testcontainers.service.connection.ServiceConnection
import org.springframework.http.HttpEntity
import org.springframework.http.HttpHeaders
import org.springframework.http.HttpMethod
import org.springframework.http.HttpStatus
import org.springframework.http.MediaType
import org.springframework.http.ResponseEntity
import org.testcontainers.containers.PostgreSQLContainer
import org.testcontainers.junit.jupiter.Container
import org.testcontainers.junit.jupiter.Testcontainers
import java.time.Duration
import java.time.Instant
import java.util.UUID

/** Prices and quotes against a real PostgreSQL migrated by Flyway. */
@Tag("integration")
@Testcontainers
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class PricingApiIT {

    companion object {
        @Container
        @ServiceConnection
        @JvmStatic
        val postgres = PostgreSQLContainer("postgres:16.4-alpine")
    }

    @Autowired
    lateinit var http: TestRestTemplate

    private fun sku() = "SKU-" + UUID.randomUUID().toString().substring(0, 8).uppercase()

    private fun put(sku: String, body: String, ifMatch: String? = null): ResponseEntity<Map<*, *>> =
        http.exchange("/v1/prices/$sku", HttpMethod.PUT, HttpEntity(body, HttpHeaders().apply {
            contentType = MediaType.APPLICATION_JSON
            ifMatch?.let { set("If-Match", it) }
        }), Map::class.java)

    private fun quote(body: String) = http.postForEntity(
        "/v1/quotes", HttpEntity(body, HttpHeaders().apply { contentType = MediaType.APPLICATION_JSON }), Map::class.java,
    )

    @Test
    fun `create, read and update a price with ETag concurrency`() {
        val sku = sku()
        val created = put(sku, """{"amountMinor":129900,"currency":"TRY"}""")
        assertThat(created.statusCode).isEqualTo(HttpStatus.CREATED)
        assertThat(created.headers.eTag).isEqualTo("\"1\"")

        val read = http.getForEntity("/v1/prices/$sku", Map::class.java)
        assertThat(read.statusCode).isEqualTo(HttpStatus.OK)
        assertThat(read.headers.eTag).isEqualTo("\"1\"")
        assertThat(read.body!!["price"]).isEqualTo(mapOf("amountMinor" to 129900, "currency" to "TRY"))

        assertThat(put(sku, """{"amountMinor":1,"currency":"TRY"}""").statusCode).isEqualTo(HttpStatus.PRECONDITION_REQUIRED)

        val updated = put(sku, """{"amountMinor":119900,"currency":"TRY"}""", "\"1\"")
        assertThat(updated.statusCode).isEqualTo(HttpStatus.OK)
        assertThat(updated.headers.eTag).isEqualTo("\"2\"")

        // a second writer still holding version 1 loses
        val stale = put(sku, """{"amountMinor":99900,"currency":"TRY"}""", "\"1\"")
        assertThat(stale.statusCode).isEqualTo(HttpStatus.PRECONDITION_FAILED)
        assertThat(stale.headers.contentType.toString()).contains("application/problem+json")
        assertThat((http.getForEntity("/v1/prices/$sku", Map::class.java).body!!["price"] as Map<*, *>)["amountMinor"]).isEqualTo(119900)
    }

    @Test
    fun `invalid input is a 400 problem and unknown SKU a 404`() {
        assertThat(put(sku(), """{"amountMinor":-5,"currency":"TRY"}""").statusCode).isEqualTo(HttpStatus.BAD_REQUEST)
        assertThat(put(sku(), """{"amountMinor":5,"currency":"tl"}""").statusCode).isEqualTo(HttpStatus.BAD_REQUEST)
        assertThat(put("bad sku", """{"amountMinor":5,"currency":"TRY"}""").statusCode).isEqualTo(HttpStatus.BAD_REQUEST)
        assertThat(put(sku(), """{"currency":"TRY"}""").statusCode).isEqualTo(HttpStatus.BAD_REQUEST)
        assertThat(http.getForEntity("/v1/prices/${sku()}", Map::class.java).statusCode).isEqualTo(HttpStatus.NOT_FOUND)
    }

    @Test
    fun `list returns only priced SKUs`() {
        val a = sku(); val b = sku(); val missing = sku()
        put(a, """{"amountMinor":100,"currency":"TRY"}"""); put(b, """{"amountMinor":200,"currency":"TRY"}""")

        val list = http.getForEntity("/v1/prices?sku=$a&sku=$b&sku=$missing", Map::class.java)
        assertThat(list.statusCode).isEqualTo(HttpStatus.OK)
        assertThat((list.body!!["items"] as List<*>).map { (it as Map<*, *>)["sku"] }).containsExactlyInAnyOrder(a, b)
    }

    @Test
    fun `a quote freezes prices, totals the basket and can be read back`() {
        val shoe = sku(); val sock = sku()
        put(shoe, """{"amountMinor":129900,"currency":"TRY"}"""); put(sock, """{"amountMinor":4950,"currency":"TRY"}""")

        val created = quote("""{"lines":[{"sku":"$shoe","quantity":2},{"sku":"$sock","quantity":3}]}""")
        assertThat(created.statusCode).isEqualTo(HttpStatus.CREATED)
        val q = created.body!!
        assertThat(q["total"]).isEqualTo(mapOf("amountMinor" to 274650, "currency" to "TRY"))
        val ttl = Duration.between(Instant.parse(q["createdAt"] as String), Instant.parse(q["expiresAt"] as String))
        assertThat(ttl).isEqualTo(Duration.ofMinutes(15))

        // a later price change does not alter the stored quote
        put(shoe, """{"amountMinor":1,"currency":"TRY"}""", "\"1\"")
        val read = http.getForEntity(created.headers.location.toString(), Map::class.java)
        assertThat(read.statusCode).isEqualTo(HttpStatus.OK)
        assertThat(read.body!!["total"]).isEqualTo(q["total"])
        assertThat((read.body!!["lines"] as List<*>).map { (it as Map<*, *>)["sku"] }).containsExactly(shoe, sock)
    }

    @Test
    fun `decimal or string numbers are rejected, never truncated`() {
        val sku = sku()
        assertThat(put(sku, """{"amountMinor":1299.99,"currency":"TRY"}""").statusCode).isEqualTo(HttpStatus.BAD_REQUEST)
        assertThat(put(sku, """{"amountMinor":"1299","currency":"TRY"}""").statusCode).isEqualTo(HttpStatus.BAD_REQUEST)
        assertThat(http.getForEntity("/v1/prices/$sku", Map::class.java).statusCode).isEqualTo(HttpStatus.NOT_FOUND)
        put(sku, """{"amountMinor":100,"currency":"TRY"}""")
        assertThat(quote("""{"lines":[{"sku":"$sku","quantity":1.9}]}""").statusCode).isEqualTo(HttpStatus.BAD_REQUEST)
    }

    @Test
    fun `framework 400s carry our problem type and correlation id`() {
        val r = http.exchange("/v1/prices/${sku()}", HttpMethod.PUT, HttpEntity("{not json", HttpHeaders().apply {
            contentType = MediaType.APPLICATION_JSON
            set("X-Correlation-Id", "it-corr-400")
        }), Map::class.java)
        assertThat(r.statusCode).isEqualTo(HttpStatus.BAD_REQUEST)
        assertThat(r.body!!["type"]).isEqualTo("https://commerceflow.dev/problems/invalid-request")
        assertThat(r.body!!["correlationId"]).isEqualTo("it-corr-400")
    }

    @Test
    fun `If-Match star, lists and weak tags`() {
        val sku = sku()
        assertThat(put(sku, """{"amountMinor":100,"currency":"TRY"}""", "*").statusCode).isEqualTo(HttpStatus.PRECONDITION_FAILED)
        put(sku, """{"amountMinor":100,"currency":"TRY"}""")
        assertThat(put(sku, """{"amountMinor":200,"currency":"TRY"}""", "W/\"1\"").statusCode).isEqualTo(HttpStatus.PRECONDITION_FAILED)
        assertThat(put(sku, """{"amountMinor":200,"currency":"TRY"}""", "\"7\", \"1\"").statusCode).isEqualTo(HttpStatus.OK)
        assertThat(put(sku, """{"amountMinor":300,"currency":"TRY"}""", "*").headers.eTag).isEqualTo("\"3\"")
    }

    @Test
    fun `price cap, oversized baskets and mixed currencies are rejected cleanly`() {
        assertThat(put(sku(), """{"amountMinor":10000000000001,"currency":"TRY"}""").statusCode).isEqualTo(HttpStatus.BAD_REQUEST)
        val lines = (1..51).joinToString(",") { """{"sku":"OVER-$it","quantity":1}""" }
        assertThat(quote("""{"lines":[$lines]}""").statusCode).isEqualTo(HttpStatus.BAD_REQUEST)

        val tl = sku(); val eur = sku()
        put(tl, """{"amountMinor":100,"currency":"TRY"}"""); put(eur, """{"amountMinor":100,"currency":"EUR"}""")
        val mixed = quote("""{"lines":[{"sku":"$tl","quantity":1},{"sku":"$eur","quantity":1}]}""")
        assertThat(mixed.statusCode).isEqualTo(HttpStatus.UNPROCESSABLE_ENTITY)
        assertThat(mixed.body!!["type"]).isEqualTo("https://commerceflow.dev/problems/mixed-currency")
    }

    @Test
    fun `quote timestamps in the response equal later reads and expired is reported`() {
        val sku = sku()
        put(sku, """{"amountMinor":100,"currency":"TRY"}""")
        val created = quote("""{"lines":[{"sku":"$sku","quantity":1}]}""").body!!
        assertThat(created["expired"]).isEqualTo(false)
        val read = http.getForEntity("/v1/quotes/${created["id"]}", Map::class.java).body!!
        assertThat(read["createdAt"]).isEqualTo(created["createdAt"])
        assertThat(read["expiresAt"]).isEqualTo(created["expiresAt"])
    }

    @Test
    fun `quoting unpriced SKUs is a 422 naming them, and nothing is stored`() {
        val shoe = sku(); val missing = sku()
        put(shoe, """{"amountMinor":100,"currency":"TRY"}""")

        val r = quote("""{"lines":[{"sku":"$shoe","quantity":1},{"sku":"$missing","quantity":1}]}""")
        assertThat(r.statusCode).isEqualTo(HttpStatus.UNPROCESSABLE_ENTITY)
        assertThat(r.body!!["skus"]).isEqualTo(listOf(missing))
        assertThat(quote("""{"lines":[]}""").statusCode).isEqualTo(HttpStatus.BAD_REQUEST)
        assertThat(http.getForEntity("/v1/quotes/${UUID.randomUUID()}", Map::class.java).statusCode).isEqualTo(HttpStatus.NOT_FOUND)
    }
}
