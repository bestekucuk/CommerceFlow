import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("org.springframework.boot") version "3.3.5"
    id("io.spring.dependency-management") version "1.1.6"
    kotlin("jvm") version "2.0.21"
    kotlin("plugin.spring") version "2.0.21"
    id("com.github.davidmc24.gradle.plugin.avro") version "1.9.1"
}

group = "com.commerceflow"
version = "0.0.1-SNAPSHOT"

// Bytecode 17 so the build runs on any JDK 17+ (local machines, CI, Docker).
java {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
        freeCompilerArgs.addAll("-Xjsr305=strict")
    }
}

repositories {
    mavenCentral()
    maven("https://packages.confluent.io/maven/")
}

// Event contracts are generated from contracts/events (CF-003). Override with
// -PcontractsDir=/contracts inside Docker builds. Generated code stays in build/.
val contractsDir = providers.gradleProperty("contractsDir").orElse("../../contracts").get()

avro {
    stringType.set("String")
}

tasks.named<com.github.davidmc24.gradle.plugin.avro.GenerateAvroJavaTask>("generateAvroJava") {
    // only the contracts this service produces; common types first so references resolve
    setSource(files("$contractsDir/events/common", "$contractsDir/events/product"))
}

// Kotlin must see the generated Java classes (javac still compiles them).
kotlin.sourceSets.named("main") {
    kotlin.srcDir(tasks.named("generateAvroJava"))
}

dependencies {
    implementation("org.apache.avro:avro:1.11.4")
    implementation("io.confluent:kafka-avro-serializer:7.7.1")
    implementation("io.opentelemetry:opentelemetry-api:1.43.0")
    implementation("net.logstash.logback:logstash-logback-encoder:8.0")
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("org.springframework.boot:spring-boot-starter-actuator")
    implementation("org.springframework.boot:spring-boot-starter-jdbc")
    implementation("org.flywaydb:flyway-core")
    implementation("org.flywaydb:flyway-database-postgresql")
    implementation("com.fasterxml.jackson.module:jackson-module-kotlin")
    implementation("org.jetbrains.kotlin:kotlin-reflect")
    implementation("io.micrometer:micrometer-registry-prometheus")
    runtimeOnly("org.postgresql:postgresql")

    testImplementation("org.springframework.boot:spring-boot-starter-test")
    testImplementation("org.springframework.boot:spring-boot-testcontainers")
    testImplementation("org.testcontainers:junit-jupiter")
    testImplementation("org.testcontainers:postgresql")
    testImplementation("com.tngtech.archunit:archunit-junit5:1.3.0")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

// Unit tests only: `./gradlew build` must pass without Docker.
tasks.test {
    useJUnitPlatform { excludeTags("integration") }
}

// Testcontainers tests: `./gradlew integrationTest` (requires Docker).
val integrationTest by tasks.registering(Test::class) {
    description = "Runs Testcontainers integration tests (requires Docker)."
    group = "verification"
    useJUnitPlatform { includeTags("integration") }
    testClassesDirs = sourceSets.test.get().output.classesDirs
    classpath = sourceSets.test.get().runtimeClasspath
    shouldRunAfter(tasks.test)
    // Docker Engine 29+ rejects API versions below 1.40; docker-java defaults lower.
    systemProperty("api.version", "1.44")
}

tasks.bootJar {
    archiveFileName.set("app.jar")
}

tasks.jar {
    enabled = false
}
