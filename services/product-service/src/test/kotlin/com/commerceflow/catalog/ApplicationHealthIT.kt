package com.commerceflow.catalog

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Tag
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.test.web.client.TestRestTemplate
import org.springframework.boot.testcontainers.service.connection.ServiceConnection
import org.springframework.http.HttpStatus
import org.springframework.jdbc.core.JdbcTemplate
import org.testcontainers.containers.PostgreSQLContainer
import org.testcontainers.junit.jupiter.Container
import org.testcontainers.junit.jupiter.Testcontainers

@Tag("integration")
@Testcontainers
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class ApplicationHealthIT {

    companion object {
        @Container
        @ServiceConnection
        @JvmStatic
        val postgres = PostgreSQLContainer("postgres:16-alpine")
    }

    @Autowired
    lateinit var http: TestRestTemplate

    @Autowired
    lateinit var jdbc: JdbcTemplate

    @Test
    fun `liveness and readiness are UP with a database`() {
        listOf("/actuator/health/liveness", "/actuator/health/readiness").forEach { path ->
            val response = http.getForEntity(path, String::class.java)
            assertThat(response.statusCode).isEqualTo(HttpStatus.OK)
            assertThat(response.body).contains("UP")
        }
    }

    @Test
    fun `flyway created the outbox table`() {
        val count = jdbc.queryForObject(
            "SELECT count(*) FROM information_schema.tables WHERE table_name = 'outbox'",
            Int::class.java,
        )
        assertThat(count).isEqualTo(1)
    }
}
