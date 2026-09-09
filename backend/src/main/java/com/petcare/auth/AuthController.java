package com.petcare.auth;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
@RestController
@RequestMapping("/api/auth")
class AuthController {
 private final AuthService auth;
 private final AuthRateLimiter limits;
 AuthController(AuthService auth,AuthRateLimiter limits) { this.auth=auth; this.limits=limits; }
 record Registration(@NotBlank @Email @Size(max=254) String email,@NotBlank @Size(min=10,max=72) String password,@NotBlank @Size(max=40) String name) {}
 record Login(@NotBlank @Email @Size(max=254) String email,@NotBlank @Size(max=72) String password) {}
 private String device(HttpServletRequest request) {
  String value=request.getHeader("X-Device-Name");
  if(value==null || value.isBlank()) return "Unknown device";
  value=value.replaceAll("[\\p{Cntrl}]", "").strip();
  return value.substring(0,Math.min(80,value.length()));
 }
 @PostMapping("/register") @ResponseStatus(HttpStatus.CREATED)
 Map<String,String> register(@Valid @RequestBody Registration input,Authentication user,HttpServletRequest request) {
  limits.check(request.getRemoteAddr());
  if(request.getHeader("Authorization") != null && (user == null || "anonymousUser".equals(user.getName())))
   throw new org.springframework.web.server.ResponseStatusException(HttpStatus.UNAUTHORIZED);
  return auth.register(input.email(),input.password(),input.name(),user,device(request));
 }
 @PostMapping("/login")
 Map<String,String> login(@Valid @RequestBody Login input,HttpServletRequest request) {
  limits.check(request.getRemoteAddr());
  return auth.login(input.email(),input.password(),device(request));
 }
 @PostMapping("/logout") @ResponseStatus(HttpStatus.NO_CONTENT)
 void logout(@RequestHeader("Authorization") String authorization) { auth.logout(authorization.substring(7)); }
 record PasswordChange(@NotBlank @Size(max=72) String oldPassword,@NotBlank @Size(min=10,max=72) String newPassword) {}
 @PostMapping("/password") @ResponseStatus(HttpStatus.NO_CONTENT)
 void changePassword(@Valid @RequestBody PasswordChange input,Authentication user,@RequestHeader("Authorization") String header,HttpServletRequest request) {
  limits.check(request.getRemoteAddr());
  auth.changePassword(user,header.substring(7),input.oldPassword(),input.newPassword());
 }
 @GetMapping("/sessions")
 java.util.List<Map<String,Object>> sessions(Authentication user,@RequestHeader("Authorization") String header) {
  return auth.sessions(user,header.substring(7));
 }
 @DeleteMapping("/sessions/{id}") @ResponseStatus(HttpStatus.NO_CONTENT)
 void revoke(Authentication user,@RequestHeader("Authorization") String header,@PathVariable String id) {
  auth.revokeSession(user,header.substring(7),id);
 }
 @PostMapping("/sessions/revoke-others") @ResponseStatus(HttpStatus.NO_CONTENT)
 void revokeOthers(Authentication user,@RequestHeader("Authorization") String header) {
  auth.revokeOthers(user,header.substring(7));
 }

}
