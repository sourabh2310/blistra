package com.blistra.diet.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CreateMealItemRequest {

    @NotBlank(message = "Food name is required")
    @Size(max = 200, message = "Food name cannot exceed 200 characters")
    private String name;

    @DecimalMin(value = "0.0", inclusive = false, message = "Quantity must be positive")
    @Digits(integer = 9, fraction = 3, message = "Quantity is out of range")
    private BigDecimal quantity;

    @Size(max = 50, message = "Unit cannot exceed 50 characters")
    private String unit;

    @DecimalMin(value = "0.0", message = "Calories cannot be negative")
    @Digits(integer = 8, fraction = 2, message = "Calories is out of range")
    private BigDecimal caloriesKcal;

    @DecimalMin(value = "0.0", message = "Protein cannot be negative")
    @Digits(integer = 8, fraction = 2, message = "Protein is out of range")
    private BigDecimal proteinG;

    @DecimalMin(value = "0.0", message = "Carbohydrates cannot be negative")
    @Digits(integer = 8, fraction = 2, message = "Carbohydrates is out of range")
    private BigDecimal carbohydratesG;

    @DecimalMin(value = "0.0", message = "Fat cannot be negative")
    @Digits(integer = 8, fraction = 2, message = "Fat is out of range")
    private BigDecimal fatG;

    @DecimalMin(value = "0.0", message = "Fiber cannot be negative")
    @Digits(integer = 8, fraction = 2, message = "Fiber is out of range")
    private BigDecimal fiberG;

    @Size(max = 1000, message = "Item notes cannot exceed 1000 characters")
    private String notes;
}