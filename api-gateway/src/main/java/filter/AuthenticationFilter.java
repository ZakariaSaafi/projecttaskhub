package filter;

import org.springframework.cloud.gateway.filter.GatewayFilterChain;
import org.springframework.cloud.gateway.filter.GlobalFilter;
import org.springframework.core.Ordered;
import org.springframework.http.HttpHeaders;
import org.springframework.http.server.reactive.ServerHttpRequest;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ServerWebExchange;
import reactor.core.publisher.Mono;

@Component
public class AuthenticationFilter implements GlobalFilter, Ordered {

    @Override
    public Mono<Void> filter(ServerWebExchange exchange, GatewayFilterChain chain) {
        ServerHttpRequest request = exchange.getRequest();

        // Ajouter des headers personnalisés pour les microservices
        ServerHttpRequest.Builder mutatedRequest = request.mutate();

        // Extraire les informations d'authentification et les passer aux services
        String authHeader = request.getHeaders().getFirst(HttpHeaders.AUTHORIZATION);
        if (authHeader != null && authHeader.startsWith("Bearer ")) {
            mutatedRequest.header("X-User-Token", authHeader.substring(7));
        }

        return chain.filter(exchange.mutate().request(mutatedRequest.build()).build());
    }

    @Override
    public int getOrder() {
        return -1;
    }
}
