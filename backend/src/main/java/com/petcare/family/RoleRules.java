package com.petcare.family;
import java.time.Instant;
import java.util.*;
import com.petcare.benefits.HouseholdBenefits;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;
public final class RoleRules {
 public static final String FULL="CARE,HEALTH,MEMORIES,PETS,REPORTS";
 public static String validate(String role,List<String> permissions,Instant until,String home,HouseholdBenefits benefits){
  if(!Set.of("ADMIN","MEMBER","TEMP").contains(role))throw new ResponseStatusException(HttpStatus.BAD_REQUEST);
  Set<String> allowed=Set.of(FULL.split(","));
  if(permissions!=null && !allowed.containsAll(permissions))throw new ResponseStatusException(HttpStatus.BAD_REQUEST);
  String value=permissions==null?(role.equals("TEMP")?"CARE":FULL):String.join(",",new TreeSet<>(permissions));
  boolean custom=!new HashSet<>(Arrays.asList(value.split(","))).equals(allowed);
  if(role.equals("TEMP")||until!=null||(!role.equals("ADMIN")&&custom))benefits.requireExtended(home);
  if(role.equals("TEMP") && until==null || role.equals("ADMIN") && until!=null || until!=null&&!until.isAfter(Instant.now()))throw new ResponseStatusException(HttpStatus.BAD_REQUEST);
  return role.equals("ADMIN")?FULL:value;
 }
}
