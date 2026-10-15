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
RUN useradd --system --no-create-home blistra && mkdir -p /tmp/blistra-documents && chown blistra /tmp/blistra-documents
COPY --from=build /app/app.jar app.jar
USER blistra
ENV SPRING_PROFILES_ACTIVE=prod \
    DOCUMENTS_STORAGE_ROOT=/tmp/blistra-documents \
    JAVA_TOOL_OPTIONS="-Xmx320m -XX:+UseSerialGC -XX:MaxMetaspaceSize=128m"
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=90s CMD ["sh", "-c", "wget -qO- http://localhost:${PORT:-8080}/health || exit 1"]
ENTRYPOINT ["java", "-jar", "app.jar"]
