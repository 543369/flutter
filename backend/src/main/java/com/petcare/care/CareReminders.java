package com.petcare.care;
import java.util.List;
import java.util.Map;
import org.springframework.jdbc.core.JdbcTemplate;
public final class CareReminders {
 private CareReminders() {}
 public static List<Map<String,Object>> list(JdbcTemplate db,String home) {
  return db.query("SELECT t.id,t.pet_id,t.title,t.due_at,p.name FROM care_tasks t JOIN pets p ON p.id=t.pet_id WHERE p.household_id=? AND t.completed=FALSE AND t.cancelled=FALSE AND t.due_at>CURRENT_TIMESTAMP(6) ORDER BY t.due_at,t.id LIMIT 60",(r,n)->Map.<String,Object>of("id",r.getString(1),"petId",r.getString(2),"title",r.getString(3),"dueAt",r.getTimestamp(4).toInstant().toString(),"petName",r.getString(5),"completed",false),home);
 }
}
