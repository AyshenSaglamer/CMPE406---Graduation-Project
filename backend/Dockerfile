# DiaMate backend image. Build from this folder: docker build -t diamate-backend .
# Configuration comes only from environment variables at run time (POSTGRES_*, JWT_SECRET, AI_SERVICE_BASE_URL, ...);
# .env is never copied into the image (see .dockerignore).

# ---- build: Maven + JDK, thrown away after the jar is built ----
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /build
# Dependencies first: this layer is reused as long as pom.xml does not change, so a code change does not download
# every library again.
COPY pom.xml .
RUN mvn -B -q dependency:go-offline
COPY src ./src
# Tests run in CI / before a commit (mvn test); the image build only packages.
RUN mvn -B -q -DskipTests package

# ---- run: JRE only, no build tools, not root ----
FROM eclipse-temurin:21-jre
RUN groupadd --system diamate && useradd --system --gid diamate --no-create-home --shell /usr/sbin/nologin diamate
WORKDIR /app
# Owned by root and only readable for others: the application user can run the jar but not replace it.
COPY --from=build /build/target/*.jar app.jar
# A process that is broken into can only do what this user may do: no root, no writable application files.
USER diamate
EXPOSE 8080
# Heap follows the container's memory limit instead of the host's memory.
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75", "-jar", "app.jar"]
