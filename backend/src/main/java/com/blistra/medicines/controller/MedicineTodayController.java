package com.blistra.medicines.controller;

import com.blistra.medicines.application.MedicineTodayService;
import com.blistra.medicines.dto.MedicineTodayResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;

@RestController
@RequestMapping("/api/v1/medicines/today")
@Tag(name = "Medicines - Today", description = "Expected doses for the user's current local date (user-recorded data, not medical advice)")
public class MedicineTodayController {

    private final MedicineTodayService todayService;

    public MedicineTodayController(MedicineTodayService todayService) {
        this.todayService = todayService;
    }

    @GetMapping
    @Operation(summary = "Get today's expected doses",
            description = "Expands the authenticated user's active schedules for one calendar day "
                    + "and matches slots against recorded doses. Unrecorded slots stay PENDING; "
                    + "nothing is auto-marked missed.")
    public ResponseEntity<MedicineTodayResponse> today(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date,
            @RequestParam(required = false) Integer offsetMinutes) {
        return ResponseEntity.ok(todayService.getToday(date, offsetMinutes));
    }
}
