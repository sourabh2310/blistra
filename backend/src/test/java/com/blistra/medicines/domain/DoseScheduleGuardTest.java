package com.blistra.medicines.domain;

import org.junit.jupiter.api.Test;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class DoseScheduleGuardTest {

    @Test
    void scheduleFromAnotherMedicineIsRejected() {
        Medicine medA = new Medicine(null, "A");
        medA.setId(UUID.randomUUID());
        Medicine medB = new Medicine(null, "B");
        medB.setId(UUID.randomUUID());
        MedicationSchedule scheduleOfB = new MedicationSchedule(medB,
                ScheduleType.DAILY);

        DoseRecord dose = new DoseRecord(medA, DoseStatus.TAKEN);
        assertThatThrownBy(() -> dose.setSchedule(scheduleOfB))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("does not belong");
    }

    @Test
    void scheduleFromSameMedicineIsAccepted() {
        Medicine med = new Medicine(null, "A");
        med.setId(UUID.randomUUID());
        MedicationSchedule schedule = new MedicationSchedule(med, ScheduleType.DAILY);

        DoseRecord dose = new DoseRecord(med, DoseStatus.TAKEN);
        assertThatCode(() -> dose.setSchedule(schedule)).doesNotThrowAnyException();
        assertThatCode(() -> dose.setSchedule(null)).doesNotThrowAnyException();
    }
}
