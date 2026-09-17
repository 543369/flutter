package com.petcare.care;

import jakarta.validation.Validation;
import java.time.Instant;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class CareTypeValidationTests {
 @Test void acceptsWaterButRejectsUnknownType() {
  try (var factory = Validation.buildDefaultValidatorFactory()) {
   var validator = factory.getValidator();
   var due = Instant.now().plusSeconds(3600);
   assertTrue(validator.validate(new CareController.TaskInput("pet", "换水", due, null, null, "WATER")).isEmpty());
   assertFalse(validator.validate(new CareController.TaskInput("pet", "换水", due, null, null, "UNKNOWN")).isEmpty());
  }
 }
}
