# Build stage: compile the Spring Boot jar with the Maven wrapper.
FROM eclipse-temurin:21-jdk AS build
WORKDIR /app
COPY .mvn .mvn
COPY mvnw pom.xml ./
RUN chmod +x mvnw && ./mvnw -q -B dependency:go-offline
COPY src src
RUN ./mvnw -q -B -DskipTests package && cp target/*.jar app.jar

# Runtime stage: small JRE image, non-root user.
FROM eclipse-temurin:21-jre
WORKDIR /app
RUN useradd --system --no-create-home blistra
RUN apt-get update && apt-get install -y --no-install-recommends curl gosu util-linux && rm -rf /var/lib/apt/lists/*
COPY --from=build /app/app.jar app.jar
COPY docker-entrypoint.sh /app/docker-entrypoint.sh
RUN chmod +x /app/docker-entrypoint.sh
ENV SPRING_PROFILES_ACTIVE=prod \
    DOCUMENTS_STORAGE_BACKEND=postgres \
    DOCUMENTS_STORAGE_ROOT=/var/data/blistra-documents \
    JAVA_TOOL_OPTIONS="-Xmx320m -XX:+UseSerialGC -XX:MaxMetaspaceSize=128m"
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=90s CMD ["sh", "-c", "curl --fail --silent http://localhost:${PORT:-8080}/actuator/health/readiness || exit 1"]
ENTRYPOINT ["/app/docker-entrypoint.sh"]
