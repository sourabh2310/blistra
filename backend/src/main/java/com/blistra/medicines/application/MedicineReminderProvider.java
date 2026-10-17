package com.blistra.medicines.application;

import com.blistra.common.time.UserTime;
import com.blistra.notifications.domain.ReminderStatus;
import com.blistra.notifications.domain.ReminderType;
import com.blistra.notifications.dto.ReminderResponse;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;
import java.nio.charset.StandardCharsets;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/** Read-only notification projection; schedules remain owned by Medicines. */
@Component
public class MedicineReminderProvider {
    private final MedicineTodayService today;
    private final UserTime time;
    public MedicineReminderProvider(MedicineTodayService today, UserTime time) {
        this.today = today;
        this.time = time;
    }

    @Transactional(readOnly = true)
    public List<ReminderResponse> upcoming() {
        var now = OffsetDateTime.now();
        var result = new ArrayList<ReminderResponse>();
        // Bounded rolling horizon. The app refreshes on resume and mutation.
        for (int day = 0; day < 7; day++) {
            for (var dose : today.getToday(time.today().plusDays(day), null).getDoses()) {
                if (!"PENDING".equals(dose.getStatus()) || !dose.getScheduledAt().isAfter(now)) continue;
                String identity = dose.getScheduleId() + ":" + dose.getScheduledAt().toInstant();
                result.add(ReminderResponse.builder()
                        .id(UUID.nameUUIDFromBytes(identity.getBytes(StandardCharsets.UTF_8)))
                        .type(ReminderType.MEDICINE).sourceId(dose.getScheduleId())
                        .title(dose.getMedicineName()).body("Scheduled medicine reminder")
                        .scheduledAt(dose.getScheduledAt()).timezone(time.zone().getId())
                        .status(ReminderStatus.SCHEDULED).build());
            }
        }
        return result;
    }
}
