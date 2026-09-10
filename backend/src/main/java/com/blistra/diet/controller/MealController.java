package com.blistra.diet.controller;

import com.blistra.auth.security.BlistraUserPrincipal;
import com.blistra.diet.application.MealService;
import com.blistra.diet.dto.CreateMealItemRequest;
import com.blistra.diet.dto.CreateMealRequest;
import com.blistra.diet.dto.MealItemResponse;
import com.blistra.diet.dto.MealResponse;
import com.blistra.diet.dto.MealSummaryResponse;
import com.blistra.diet.dto.PageResponse;
import com.blistra.diet.dto.UpdateMealRequest;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@Validated
@RestController
@RequestMapping("/api/v1/diet/meals")
@Tag(name = "Diet Meals", description = "Meal tracking and meal items")
public class MealController {

    private final MealService mealService;

    public MealController(MealService mealService) {
        this.mealService = mealService;
    }

    @GetMapping
    @Operation(summary = "List meals",
            description = "Returns the authenticated user's meals. Provide date to see one "
                    + "local calendar day (offsetMinutes defines the UTC offset of that day). "
                    + "Without date, recent history is returned, newest first.")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "Paged meals",
                    content = @Content(schema = @Schema(implementation = MealSummaryResponse.class))),
            @ApiResponse(responseCode = "400", description = "Invalid query parameters"),
            @ApiResponse(responseCode = "401", description = "Authentication required")
    })
    public PageResponse<MealSummaryResponse> list(
            @AuthenticationPrincipal BlistraUserPrincipal principal,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date,
            @RequestParam(defaultValue = "0") @Min(-1080) @Max(1080) int offsetMinutes,
            @RequestParam(defaultValue = "0") @Min(0) int page,
            @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size) {
        return mealService.list(principal.getId(), date, offsetMinutes, page, size);
    }

    @PostMapping
    @Operation(summary = "Create a meal",
            description = "Creates a meal (with optional inline items) for the authenticated user. "
                    + "Nutrition values are optional; a simple meal records cleanly without them.")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "201", description = "Meal created",
                    content = @Content(schema = @Schema(implementation = MealResponse.class))),
            @ApiResponse(responseCode = "400", description = "Invalid request (validation error)"),
            @ApiResponse(responseCode = "401", description = "Authentication required")
    })
    public ResponseEntity<MealResponse> create(
            @AuthenticationPrincipal BlistraUserPrincipal principal,
            @Valid @RequestBody CreateMealRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(mealService.create(principal.getId(), request));
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get a meal", description = "Returns one meal including its items if owned by the user.")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "Meal",
                    content = @Content(schema = @Schema(implementation = MealResponse.class))),
            @ApiResponse(responseCode = "401", description = "Authentication required"),
            @ApiResponse(responseCode = "404", description = "Meal not found")
    })
    public MealResponse get(@AuthenticationPrincipal BlistraUserPrincipal principal,
                            @PathVariable UUID id) {
        return mealService.get(principal.getId(), id);
    }

    @PutMapping("/{id}")
    @Operation(summary = "Update a meal", description = "Updates meal-level fields. Items are managed separately.")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "Meal updated",
                    content = @Content(schema = @Schema(implementation = MealResponse.class))),
            @ApiResponse(responseCode = "400", description = "Invalid request (validation error)"),
            @ApiResponse(responseCode = "401", description = "Authentication required"),
            @ApiResponse(responseCode = "404", description = "Meal not found")
    })
    public MealResponse update(@AuthenticationPrincipal BlistraUserPrincipal principal,
                               @PathVariable UUID id,
                               @Valid @RequestBody UpdateMealRequest request) {
        return mealService.update(principal.getId(), id, request);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Delete a meal",
            description = "Deletes the meal and all of its items. Water records and other data are unaffected.")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "204", description = "Meal deleted"),
            @ApiResponse(responseCode = "401", description = "Authentication required"),
            @ApiResponse(responseCode = "404", description = "Meal not found")
    })
    public void delete(@AuthenticationPrincipal BlistraUserPrincipal principal,
                       @PathVariable UUID id) {
        mealService.delete(principal.getId(), id);
    }

    @GetMapping("/{id}/items")
    @Operation(summary = "List meal items", description = "Returns the items of an owned meal.")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "Meal items",
                    content = @Content(schema = @Schema(implementation = MealItemResponse.class))),
            @ApiResponse(responseCode = "401", description = "Authentication required"),
            @ApiResponse(responseCode = "404", description = "Meal not found")
    })
    public List<MealItemResponse> listItems(@AuthenticationPrincipal BlistraUserPrincipal principal,
                                            @PathVariable UUID id) {
        return mealService.listItems(principal.getId(), id);
    }

    @PostMapping("/{id}/items")
    @Operation(summary = "Add a meal item", description = "Adds an item to an owned meal.")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "201", description = "Meal item created",
                    content = @Content(schema = @Schema(implementation = MealItemResponse.class))),
            @ApiResponse(responseCode = "400", description = "Invalid request (validation error)"),
            @ApiResponse(responseCode = "401", description = "Authentication required"),
            @ApiResponse(responseCode = "404", description = "Meal not found")
    })
    public ResponseEntity<MealItemResponse> addItem(
            @AuthenticationPrincipal BlistraUserPrincipal principal,
            @PathVariable UUID id,
            @Valid @RequestBody CreateMealItemRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(mealService.addItem(principal.getId(), id, request));
    }

    @PutMapping("/{id}/items/{itemId}")
    @Operation(summary = "Update a meal item", description = "Updates an item within an owned meal.")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "Meal item updated",
                    content = @Content(schema = @Schema(implementation = MealItemResponse.class))),
            @ApiResponse(responseCode = "400", description = "Invalid request (validation error)"),
            @ApiResponse(responseCode = "401", description = "Authentication required"),
            @ApiResponse(responseCode = "404", description = "Meal or item not found")
    })
    public MealItemResponse updateItem(@AuthenticationPrincipal BlistraUserPrincipal principal,
                                       @PathVariable UUID id,
                                       @PathVariable UUID itemId,
                                       @Valid @RequestBody CreateMealItemRequest request) {
        return mealService.updateItem(principal.getId(), id, itemId, request);
    }

    @DeleteMapping("/{id}/items/{itemId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Delete a meal item", description = "Deletes one item from an owned meal.")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "204", description = "Meal item deleted"),
            @ApiResponse(responseCode = "401", description = "Authentication required"),
            @ApiResponse(responseCode = "404", description = "Meal or item not found")
    })
    public void deleteItem(@AuthenticationPrincipal BlistraUserPrincipal principal,
                           @PathVariable UUID id,
                           @PathVariable UUID itemId) {
        mealService.deleteItem(principal.getId(), id, itemId);
    }
}