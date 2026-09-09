package com.petcare.auth;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.List;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.filter.OncePerRequestFilter;

@Configuration
class SecurityConfig {
 @Bean SecurityFilterChain security(HttpSecurity http, JdbcTemplate db) throws Exception {
  return http.csrf(c -> c.disable())
   .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
   .authorizeHttpRequests(a -> a.dispatcherTypeMatchers(jakarta.servlet.DispatcherType.ERROR).permitAll().requestMatchers(org.springframework.http.HttpMethod.POST, "/api/session", "/api/auth/register", "/api/auth/login", "/api/auth/recovery/request", "/api/auth/recovery/confirm", "/api/auth/apple/challenge", "/api/auth/apple/login").permitAll()
    .requestMatchers("/api/health").permitAll().anyRequest().authenticated())
   .exceptionHandling(e -> e.authenticationEntryPoint((q,r,x) -> r.sendError(401)))
   .addFilterBefore(new OncePerRequestFilter() {
    @Override protected void doFilterInternal(HttpServletRequest q, HttpServletResponse r, FilterChain chain)
      throws ServletException, IOException {
     String header = q.getHeader("Authorization");
     if (header != null && header.startsWith("Bearer ") && header.length() < 256) {
      var ids = db.queryForList("SELECT account_id FROM account_sessions WHERE token_hash = ? AND expires_at > UTC_TIMESTAMP(6)", String.class, Tokens.hash(header.substring(7)));
      if (!ids.isEmpty()) db.update("UPDATE account_sessions SET last_seen_at=UTC_TIMESTAMP(6) WHERE token_hash=? AND (last_seen_at IS NULL OR last_seen_at<DATE_SUB(UTC_TIMESTAMP(6),INTERVAL 1 MINUTE))",Tokens.hash(header.substring(7)));
      if (!ids.isEmpty()) SecurityContextHolder.getContext().setAuthentication(
       new UsernamePasswordAuthenticationToken(ids.getFirst(), null, List.of()));
     }
     chain.doFilter(q, r);
    }
   }, UsernamePasswordAuthenticationFilter.class).build();
 }
}
