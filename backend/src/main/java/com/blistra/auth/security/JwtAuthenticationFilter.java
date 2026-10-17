package com.blistra.auth.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.util.StringUtils;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

public class JwtAuthenticationFilter extends OncePerRequestFilter {

    @Autowired
    private JwtProvider jwtProvider;

    @Autowired
    private UserDetailsService userDetailsService;
    @org.springframework.beans.factory.annotation.Value("${blistra.security.verified-sharing-required:true}")
    private boolean verifiedSharingRequired;

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {
        try {
            String jwt = extractJwtFromRequest(request);
            if (StringUtils.hasText(jwt)) {
                if (jwtProvider.isTokenValid(jwt)) {
                    String subject = jwtProvider.extractUsername(jwt);
                    UserDetails userDetails;
                    if (userDetailsService instanceof CustomUserDetailsService custom) {
                        userDetails = custom.loadBySubject(subject);
                    } else {
                        userDetails = userDetailsService.loadUserByUsername(subject);
                    }
                    if (userDetails instanceof BlistraUserPrincipal principal
                            && !jwtProvider.matchesSessionVersion(jwt, principal.getSessionVersion())) {
                        throw new org.springframework.security.authentication.BadCredentialsException("Session revoked");
                    }
                    UsernamePasswordAuthenticationToken authentication =
                            new UsernamePasswordAuthenticationToken(userDetails, null, userDetails.getAuthorities());
                    authentication.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
                    SecurityContextHolder.getContext().setAuthentication(authentication);
                } else {
                    // Invalid/expired/malformed token - do not authenticate, let the
                    // authentication entry point handle 401 for protected endpoints
                    logger.debug("Invalid JWT token received");
                }
            }
        } catch (Exception ex) {
            // Do not log stack traces for invalid tokens - they are expected
            logger.debug("JWT authentication failed: " + ex.getMessage());
        }
        var authentication = SecurityContextHolder.getContext().getAuthentication();
        String path = request.getRequestURI();
        if (verifiedSharingRequired && authentication != null
                && authentication.getPrincipal() instanceof BlistraUserPrincipal principal
                && !principal.isEmailVerified() && !java.util.Set.of("GET", "HEAD", "OPTIONS").contains(request.getMethod())
                && (path.startsWith("/api/v1/documents") || path.startsWith("/api/v1/profile/avatar")
                    || path.startsWith("/api/v1/finance/"))) {
            response.setStatus(403);
            response.setContentType("application/json");
            response.getWriter().write("{\"status\":403,\"code\":\"VERIFICATION_REQUIRED\",\"message\":\"Verify your email in Profile before uploading files or using shared finances.\"}");
            return;
        }
        filterChain.doFilter(request, response);
    }

    private String extractJwtFromRequest(HttpServletRequest request) {
        String bearerToken = request.getHeader("Authorization");
        if (StringUtils.hasText(bearerToken) && bearerToken.startsWith("Bearer ")) {
            return bearerToken.substring(7);
        }
        return null;
    }
}
