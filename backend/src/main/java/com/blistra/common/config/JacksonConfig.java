package com.blistra.common.config;

import org.springframework.boot.jackson.autoconfigure.JsonMapperBuilderCustomizer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import tools.jackson.databind.module.SimpleModule;
import tools.jackson.databind.ser.std.ToStringSerializerBase;

import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;

/**
 * Serialises java.time values using their canonical {@code toString()} form, so
 * that timestamps are rendered the same way the rest of the Java ecosystem
 * prints them (e.g. {@code 10:00} rather than {@code 10:00:00} when the seconds
 * part is zero). Deserialisation is left to Jackson's default handlers.
 */
@Configuration
public class JacksonConfig {

    @Bean
    public JsonMapperBuilderCustomizer javaTimeToStringCustomizer() {
        SimpleModule module = new SimpleModule("java-time-to-string");
        module.addSerializer(OffsetDateTime.class, new ToStringSerializerBase(OffsetDateTime.class) {
            @Override
            public String valueToString(Object value) {
                return value.toString();
            }
        });
        module.addSerializer(Instant.class, new ToStringSerializerBase(Instant.class) {
            @Override
            public String valueToString(Object value) {
                return value.toString();
            }
        });
        module.addSerializer(LocalDateTime.class, new ToStringSerializerBase(LocalDateTime.class) {
            @Override
            public String valueToString(Object value) {
                return value.toString();
            }
        });
        module.addSerializer(LocalDate.class, new ToStringSerializerBase(LocalDate.class) {
            @Override
            public String valueToString(Object value) {
                return value.toString();
            }
        });
        return builder -> builder.addModule(module);
    }
}