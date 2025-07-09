FROM openjdk:17-jdk-slim

LABEL maintainer="ProjectTaskHub Team"
LABEL service="task-service"
LABEL version="1.0.0"

ENV JAVA_OPTS=""
ENV SPRING_PROFILES_ACTIVE="docker"

RUN groupadd -r taskservice && useradd -r -g taskservice taskservice

WORKDIR /app

COPY target/task-service-1.0.0.jar app.jar

RUN chown taskservice:taskservice app.jar

USER taskservice

EXPOSE 8082

HEALTHCHECK --interval=30s --timeout=3s --start-period=45s --retries=3 \
  CMD curl -f http://localhost:8082/actuator/health || exit 1

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]