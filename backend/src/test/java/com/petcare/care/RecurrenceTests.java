package com.petcare.care;

import org.junit.jupiter.api.Test;
import java.time.*;
import java.util.List;
import static org.junit.jupiter.api.Assertions.*;

class RecurrenceTests {
    @Test void dailyRetainsWallClockAcrossSpringDst() {
        Instant start = Instant.parse("2026-03-07T13:00:00Z");
        assertEquals(List.of(start, Instant.parse("2026-03-08T12:00:00Z"), Instant.parse("2026-03-09T12:00:00Z")),
            Recurrence.between(start,"America/New_York","DAILY",start,Instant.parse("2026-03-09T13:00:00Z")));
    }
    @Test void nonexistentTimeDoesNotShiftRemainingSeries() {
        Instant start = Instant.parse("2026-03-07T07:30:00Z");
        assertEquals(List.of(start,Instant.parse("2026-03-08T07:30:00Z"),Instant.parse("2026-03-09T06:30:00Z")),
            Recurrence.between(start,"America/New_York","DAILY",start,Instant.parse("2026-03-09T08:00:00Z")));
    }
    @Test void weeklyRetainsWeekdayAcrossFallDst() {
        Instant start = Instant.parse("2026-10-25T12:00:00Z");
        assertEquals(List.of(start,Instant.parse("2026-11-01T13:00:00Z"),Instant.parse("2026-11-08T13:00:00Z")),
            Recurrence.between(start,"America/New_York","WEEKLY",start,Instant.parse("2026-11-08T14:00:00Z")));
    }
    @Test void clipsToWindowWithoutShiftingAnchor() {
        assertEquals(List.of(Instant.parse("2026-09-08T02:00:00Z")),Recurrence.between(
            Instant.parse("2020-01-01T02:00:00Z"),"Asia/Shanghai","DAILY",Instant.parse("2026-09-08T00:00:00Z"),Instant.parse("2026-09-08T23:59:59Z")));
    }
    @Test void invalidFrequencyIsRejected() {
        assertThrows(IllegalArgumentException.class,()->Recurrence.between(Instant.now(),"UTC","INVALID",Instant.now(),Instant.now()));
    }
}
