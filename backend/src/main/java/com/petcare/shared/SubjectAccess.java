package com.petcare.shared;
import java.util.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;
/** Row filtering is applied BEFORE pagination and aggregation, including legacy routes. */
public final class SubjectAccess {
 private SubjectAccess(){}
 public static String and(String alias){return " AND "+sql(alias,"READ");}
 public static String sql(String alias,String level){
  Authentication auth=SecurityContextHolder.getContext().getAuthentication();
  String actor=auth==null?null:auth.getName();
  if(actor==null || !actor.matches("[a-fA-F0-9-]{36}"))return "("+alias+".subject_type='PET')";
  String owner=alias+".subject_owner='"+actor+"'";
  String grant="EXISTS(SELECT 1 FROM subject_grants sg JOIN accounts ga ON ga.id=sg.account_id WHERE sg.subject_id="+alias+".id AND sg.account_id='"+actor+"' AND ga.household_id="+alias+".household_id AND (ga.access_until IS NULL OR ga.access_until>UTC_TIMESTAMP(6))"+(level.equals("READ")?"":" AND sg.access_level='CARE'")+")";
  return "("+alias+".subject_type='PET' OR "+(level.equals("READ")?"("+owner+" OR ("+alias+".consent_revoked_at IS NULL AND "+grant+"))":"("+alias+".consent_revoked_at IS NULL AND ("+owner+" OR "+grant+"))")+")";
 }
 public static Map<String,Object> require(JdbcTemplate db,Authentication auth,String subject,String level){
  var rows=db.queryForList("SELECT p.* FROM pets p JOIN accounts a ON a.household_id=p.household_id WHERE p.id=? AND a.id=? AND (a.access_until IS NULL OR a.access_until>UTC_TIMESTAMP(6))",subject,auth.getName());
  if(rows.isEmpty())throw new ResponseStatusException(HttpStatus.NOT_FOUND);
  var row=rows.getFirst();if(row.get("subject_type").equals("PET"))return row;
  boolean owner=auth.getName().equals(row.get("subject_owner"));
  if(level.equals("MANAGE")){if(!owner)throw new ResponseStatusException(HttpStatus.FORBIDDEN,"SUBJECT_ACCESS_DENIED");return row;}
  if(row.get("consent_revoked_at")!=null && !(owner && level.equals("READ")))throw new ResponseStatusException(HttpStatus.FORBIDDEN,"SUBJECT_CONSENT_REVOKED");
  String grant=db.queryForList("SELECT access_level FROM subject_grants WHERE subject_id=? AND account_id=?",String.class,subject,auth.getName()).stream().findFirst().orElse("");
  if(!owner && (!level.equals("READ")?!grant.equals("CARE"):grant.isEmpty()))throw new ResponseStatusException(HttpStatus.FORBIDDEN,"SUBJECT_ACCESS_DENIED");
  return row;
 }
 public static void task(JdbcTemplate db,Authentication auth,String task,String level){
  var ids=db.queryForList("SELECT pet_id FROM care_tasks WHERE id=?",String.class,task);
  if(ids.isEmpty())throw new ResponseStatusException(HttpStatus.NOT_FOUND);require(db,auth,ids.getFirst(),level);
 }
 public static void type(JdbcTemplate db,String subject,String kind){
  String type=db.queryForObject("SELECT subject_type FROM pets WHERE id=?",String.class,subject);
  var human=Set.of("MEAL","DRINK","MEDICATION","REHAB","APPOINTMENT","DAILY","NURTURE","SLEEP","GROWTH","PICKUP","HANDOVER","OBSERVATION","CUSTOM");
  var pet=Set.of("FEEDING","WATER","DEWORMING","VACCINE","WALK","GROOMING","CUSTOM");
  if(!(type.equals("HUMAN")?human:pet).contains(kind))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"INVALID_SUBJECT_CARE_TYPE");
 }
}
