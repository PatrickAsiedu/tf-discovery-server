FROM maven:3.9.8 AS build-stage
LABEL name=tf-discovery-server

WORKDIR /app

# Copy only the pom.xml first to leverage Docker layer caching
COPY pom.xml .
RUN mvn -Dmaven.repo.local=/app/.m3/repository dependency:go-offline

# Copy the rest of the application source code and build
COPY src ./src
RUN mvn -Dmaven.repo.local=/app/.m3/repository package -DskipTests=true

# Stage 2: Run with Temurin 21 JRE (Jammy) for reliable cgroup support
FROM eclipse-temurin:21-jre-jammy AS production-stage
WORKDIR /app

RUN apt-get update && \
    apt-get install -y curl telnet nano tcpdump less bash && \
    rm -rf /var/lib/apt/lists/*

EXPOSE 8761

# Copy the compiled artifact from the build stage
COPY --from=build-stage /app/target/*.jar discovery-server.jar
COPY src/main/resources/application.properties /app/application.properties

ENV TZ=GMT

ENV JAVA_OPTS="-Djdk.internal.httpclient.disableHostnameVerification=true"

# Align entrypoint style with other services
ENTRYPOINT ["java", "--enable-native-access=ALL-UNNAMED", "--add-opens=java.base/sun.misc=ALL-UNNAMED", "-jar", "discovery-server.jar", "--spring.config.location=file:/app/application.properties", "--spring.profiles.active=default", "--spring.application.name=tf-discovery-server", "--server.port=8761"]


