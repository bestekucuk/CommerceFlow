package com.commerceflow.catalog.support

import com.commerceflow.events.product.ProductCreated
import com.fasterxml.jackson.databind.JsonNode
import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.databind.node.ObjectNode
import io.confluent.kafka.schemaregistry.avro.AvroSchema
import io.confluent.kafka.schemaregistry.testutil.MockSchemaRegistry
import org.junit.jupiter.api.Tag
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.testcontainers.service.connection.ServiceConnection
import org.springframework.test.context.DynamicPropertyRegistry
import org.springframework.test.context.DynamicPropertySource
import org.testcontainers.containers.PostgreSQLContainer
import org.testcontainers.junit.jupiter.Container
import org.testcontainers.junit.jupiter.Testcontainers

/**
 * Base for integration tests: real PostgreSQL (Testcontainers, migrated by Flyway) and an
 * in-memory Schema Registry scope with the ProductCreated schema registered, as the
 * pipeline does before deployment.
 */
@Tag("integration")
@Testcontainers
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
abstract class PostgresIntegrationTest {

    companion object {
        const val REGISTRY_SCOPE = "product-service-it"
        const val SUBJECT = "cf.product.events.v1-com.commerceflow.events.product.ProductCreated"

        @Container
        @ServiceConnection
        @JvmStatic
        val postgres = PostgreSQLContainer("postgres:16.4-alpine")

        @JvmStatic
        @DynamicPropertySource
        fun registry(registry: DynamicPropertyRegistry) {
            val client = MockSchemaRegistry.getClientForScope(REGISTRY_SCOPE)
            if (client.allSubjects.none { it == SUBJECT }) {
                // register the contract form: the class schema without Java-only properties
                client.register(SUBJECT, AvroSchema(contractSchema()))
            }
            registry.add("commerceflow.schema-registry.url") { "mock://$REGISTRY_SCOPE" }
        }

        /** ProductCreated schema as registered from contracts/ (no "avro.java.string" properties). */
        fun contractSchema(): String {
            val mapper = ObjectMapper()
            fun strip(node: JsonNode) {
                if (node is ObjectNode) node.remove("avro.java.string")
                node.forEach(::strip)
            }
            return mapper.readTree(ProductCreated.getClassSchema().toString()).also(::strip).toString()
        }
    }
}
