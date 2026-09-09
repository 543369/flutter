package com.petcare;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

@SpringBootTest
class PetCareApplicationTests {
	@org.springframework.beans.factory.annotation.Autowired
	org.springframework.jdbc.core.JdbcTemplate db;

	@Test
	void contextLoads() {
		org.junit.jupiter.api.Assertions.assertEquals(0, db.queryForObject("SELECT TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW())", Integer.class));
	}

}
