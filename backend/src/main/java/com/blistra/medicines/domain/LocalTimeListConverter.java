package com.blistra.medicines.domain;

import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;

import java.time.LocalTime;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.stream.Collectors;

/**
 * Converts a list of {@link LocalTime} values to and from a comma-separated
 * text column (e.g. {@code 08:00,20:00}).
 */
@Converter
public class LocalTimeListConverter implements AttributeConverter<List<LocalTime>, String> {

    @Override
    public String convertToDatabaseColumn(List<LocalTime> attribute) {
        if (attribute == null || attribute.isEmpty()) {
            return "";
        }
        return attribute.stream()
                .map(LocalTime::toString)
                .collect(Collectors.joining(","));
    }

    @Override
    public List<LocalTime> convertToEntityAttribute(String dbData) {
        if (dbData == null || dbData.isBlank()) {
            return new ArrayList<>();
        }
        return Arrays.stream(dbData.split(","))
                .map(String::trim)
                .filter(part -> !part.isEmpty())
                .map(LocalTime::parse)
                .collect(Collectors.toCollection(ArrayList::new));
    }
}