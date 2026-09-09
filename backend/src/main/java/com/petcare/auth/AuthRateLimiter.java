package com.petcare.auth;
import java.util.HashMap;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ResponseStatusException;
@Component
class AuthRateLimiter {
 private record Window(long starts, int count) {}
 private final Map<String,Window> attempts=new HashMap<>();
 synchronized void check(String address) {
  long now=System.currentTimeMillis();
  attempts.entrySet().removeIf(e -> now-e.getValue().starts()>60000);
  Window window=attempts.getOrDefault(address,new Window(now,0));
  if(window.count()>=20 || attempts.size()>10000) throw new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS);
  attempts.put(address,new Window(window.starts(),window.count()+1));
 }
}
