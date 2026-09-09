package com.petcare.care;

import java.time.*;
import java.time.temporal.ChronoUnit;
import java.util.*;

final class Recurrence {
    // Derive each occurrence from the original local time, so a DST gap does not
    // permanently shift the remaining series by an hour.
    static List<Instant> between(Instant start, String zone, String frequency, Instant from, Instant through) {
        ZoneId id = ZoneId.of(zone);
        LocalDateTime anchor = LocalDateTime.ofInstant(start, id);
        int step = switch (frequency) {
            case "DAILY" -> 1;
            case "WEEKLY" -> 7;
            default -> throw new IllegalArgumentException("Unsupported frequency");
        };
        long days = ChronoUnit.DAYS.between(anchor.toLocalDate(), from.atZone(id).toLocalDate());
        long index = Math.max(0, days / step - 1);
        List<Instant> result = new ArrayList<>();
        for (; ; index++) {
            Instant occurrence = index == 0 ? start : anchor.plusDays(index * step).atZone(id).toInstant();
            if (occurrence.isAfter(through)) break;
            if (!occurrence.isBefore(from)) result.add(occurrence);
        }
        return result;
    }
}
