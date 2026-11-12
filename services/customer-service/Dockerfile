# syntax=docker/dockerfile:1.7
# Build context: this folder. Scripts also pass --build-context contracts=contracts for
# future Avro code generation; it is unused until CF-002/CF-003.
FROM eclipse-temurin:17-jdk AS build
WORKDIR /src
COPY gradlew settings.gradle.kts build.gradle.kts ./
COPY gradle ./gradle
RUN chmod +x gradlew && ./gradlew --no-daemon --quiet dependencies > /dev/null
COPY src ./src
RUN ./gradlew --no-daemon bootJar -x test

FROM eclipse-temurin:17-jre
RUN useradd --system --uid 10001 app
WORKDIR /app
COPY --from=build /src/build/libs/app.jar /app/app.jar
USER 10001
EXPOSE 8085
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75", "-jar", "/app/app.jar"]
