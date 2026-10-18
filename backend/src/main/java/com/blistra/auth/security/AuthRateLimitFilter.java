package com.blistra.auth.security;

import com.blistra.common.exception.TooManyRequestsException;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.web.filter.OncePerRequestFilter;
import java.io.IOException;

public class AuthRateLimitFilter extends OncePerRequestFilter {
    private final AuthRateLimiter limiter;
    private final TrustedClientAddress addresses;
    private final int globalMaximum;
    public AuthRateLimitFilter(AuthRateLimiter limiter,TrustedClientAddress addresses,int globalMaximum) {
        this.limiter = limiter; this.addresses=addresses;
        this.globalMaximum=Math.min(1000000,Math.max(1,globalMaximum));
    }
    @Override protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
            FilterChain chain) throws ServletException, IOException {
        if (request.getRequestURI().startsWith("/api/v1/auth/") && !"OPTIONS".equals(request.getMethod())) {
            try {
                limiter.attempt("auth-global", "all", globalMaximum);
                limiter.attempt("auth-source", addresses.resolve(request), 100);
            } catch (TooManyRequestsException e) {
                response.setStatus(429);
                response.setContentType("application/json");
                response.setHeader("Retry-After", "900");
                response.getWriter().write("{\"status\":429,\"code\":\"RATE_LIMITED\",\"message\":\"Too many attempts. Please try again later.\",\"retryAfterSeconds\":900}");
                return;
            }
        }
        chain.doFilter(request, response);
    }
}
