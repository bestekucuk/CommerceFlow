# syntax=docker/dockerfile:1.7
# Build context: this folder plus the named context `contracts` (Avro code generation):
#   docker build --build-context contracts=contracts services/product-service
FROM eclipse-temurin:17-jdk AS build
WORKDIR /src
COPY --from=contracts . /contracts
COPY gradlew settings.gradle.kts build.gradle.kts ./
COPY gradle ./gradle
RUN chmod +x gradlew && ./gradlew --no-daemon --quiet dependencies -PcontractsDir=/contracts > /dev/null
COPY src ./src
RUN ./gradlew --no-daemon bootJar -x test -PcontractsDir=/contracts

FROM eclipse-temurin:17-jre
# OpenTelemetry Java agent: traces for HTTP, JDBC and logs (trace_id/span_id in the MDC).
# Disabled with OTEL_JAVAAGENT_ENABLED=false.
# (ADD --chmod would also apply 644 to the new /otel directory, making it untraversable
# for the non-root user, so permissions are set explicitly.)
ADD --checksum=sha256:fa039f86082b559e53283a863e03de5df7db4bdb4840c5cbb8bf38f292987d5b https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v2.9.0/opentelemetry-javaagent.jar /otel/opentelemetry-javaagent.jar
RUN chmod 755 /otel && chmod 644 /otel/opentelemetry-javaagent.jar && useradd --system --uid 10001 app
WORKDIR /app
COPY --from=build /src/build/libs/app.jar /app/app.jar
USER 10001
EXPOSE 8081
ENTRYPOINT ["java", "-javaagent:/otel/opentelemetry-javaagent.jar", "-XX:MaxRAMPercentage=75", "-jar", "/app/app.jar"]
