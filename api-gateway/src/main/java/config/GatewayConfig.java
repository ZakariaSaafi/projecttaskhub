package config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.cloud.gateway.route.builder.RouteLocatorBuilder;
import org.springframework.cloud.gateway.route.RouteLocator;

@Configuration
public class GatewayConfig {

    @Bean
    public RouteLocator customRouteLocator(RouteLocatorBuilder builder) {
        return builder.routes()
                .route("project-service", r -> r.path("/api/projects/**")
                        .filters(f -> f
                                .rewritePath("/api/projects/(?<segment>.*)", "/${segment}")
                                .addRequestHeader("X-Gateway", "api-gateway")
                        )
                        .uri("lb://project-service"))
                .route("task-service", r -> r.path("/api/tasks/**")
                        .filters(f -> f
                                .rewritePath("/api/tasks/(?<segment>.*)", "/${segment}")
                                .addRequestHeader("X-Gateway", "api-gateway")
                        )
                        .uri("lb://task-service"))
                .build();
    }
}