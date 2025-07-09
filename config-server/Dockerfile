FROM openjdk:17-jdk-slim

LABEL maintainer="ProjectTaskHub Team"
LABEL service="config-server"
LABEL version="1.0.0"

ENV JAVA_OPTS=""
ENV SPRING_PROFILES_ACTIVE="docker"

RUN groupadd -r configservice && useradd -r -g configservice configservice

WORKDIR /app

COPY target/config-server-1.0.0.jar app.jar

RUN chown configservice:configservice app.jar

USER configservice

EXPOSE 8888

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD curl -f http://localhost:8888/actuator/health || exit 1

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]