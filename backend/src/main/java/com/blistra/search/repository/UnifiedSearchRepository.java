package com.blistra.search.repository;

import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.UUID;

/**
 * Unified search over the user's data using a single parametrised SQL UNION
 * query. Each searchable source table is one UNION branch; the branch set is
 * driven by the requested {@code modules} (whitelisted, never user input), so
 * ownership, free-text matching, date-range filtering, honest totals and
 * correct cursor-based pagination all happen in the database in one round trip.
 */
@Repository
public class UnifiedSearchRepository {

    private final NamedParameterJdbcTemplate jdbc;

    public UnifiedSearchRepository(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public record Row(String module, String resultType, UUID id, String title,
                      String subtitle, OffsetDateTime ts) {
    }

    public long count(UUID userId, Set<String> modules, String term,
                      OffsetDateTime from, OffsetDateTime to) {
        String sql = "SELECT COUNT(*) FROM ( " + union(modules) + " ) m";
        Long n = jdbc.queryForObject(sql, params(userId, term, from, to), Long.class);
        return n == null ? 0 : n;
    }

    public List<Row> findPage(UUID userId, Set<String> modules, String term,
                              OffsetDateTime from, OffsetDateTime to, int limit, int offset) {
        String sql = """
                SELECT module, result_type, id, title, subtitle, ts
                FROM ( %s ) m
                ORDER BY m.ts DESC NULLS LAST, m.module, m.result_type, m.id
                LIMIT :limit OFFSET :offset
                """.formatted(union(modules));
        MapSqlParameterSource p = params(userId, term, from, to);
        p.addValue("limit", limit);
        p.addValue("offset", offset);
        return jdbc.query(sql, p, (rs, rowNum) -> {
            OffsetDateTime ts = rs.getObject("ts", OffsetDateTime.class);
            return new Row(
                    rs.getString("module"),
                    rs.getString("result_type"),
                    rs.getObject("id", UUID.class),
                    rs.getString("title"),
                    rs.getString("subtitle"),
                    ts);
        });
    }

    private MapSqlParameterSource params(UUID userId, String term, OffsetDateTime from, OffsetDateTime to) {
        return new MapSqlParameterSource()
                .addValue("userId", userId)
                .addValue("term", term)
                .addValue("from", from)
                .addValue("to", to);
    }

    private String union(Set<String> modules) {
        List<String> selects = new ArrayList<>();
        if (modules.contains(MODULE_PLANNER)) {
            selects.add(plannerTask());
            selects.add(plannerTaskList());
            selects.add(plannerEvent());
        }
        if (modules.contains(MODULE_MEDICINES)) {
            selects.add(medicine());
        }
        if (modules.contains(MODULE_HEALTH)) {
            selects.add(healthEvent());
            selects.add(healthAppointment());
            selects.add(healthSymptomLog());
            selects.add(healthActivity());
            selects.add(healthMeasurement());
            selects.add(healthSleepRecord());
        }
        if (modules.contains(MODULE_DIET)) {
            selects.add(meal());
            selects.add(mealItem());
            selects.add(dietProfile());
            selects.add(waterIntake());
        }
        if (modules.contains(MODULE_HABITS)) {
            selects.add(habit());
        }
        if (modules.contains(MODULE_FINANCE)) {
            selects.add(financeAccount());
            selects.add(financeCategory());
            selects.add(financeTransaction());
            selects.add(financeTransfer());
        }
        if (modules.contains(MODULE_DOCUMENTS)) {
            selects.add(document());
        }
        return String.join(" UNION ALL ", selects);
    }

    private static final String MODULE_PLANNER = "PLANNER";
    private static final String MODULE_MEDICINES = "MEDICINES";
    private static final String MODULE_HEALTH = "HEALTH";
    private static final String MODULE_DIET = "DIET";
    private static final String MODULE_HABITS = "HABITS";
    private static final String MODULE_FINANCE = "FINANCE";
    private static final String MODULE_DOCUMENTS = "DOCUMENTS";

    public static Set<String> allModules() {
        return Set.of(MODULE_PLANNER, MODULE_MEDICINES, MODULE_HEALTH, MODULE_DIET,
                MODULE_HABITS, MODULE_FINANCE, MODULE_DOCUMENTS);
    }

    public static String normalizeModule(String type) {
        if (type == null || type.isBlank()) {
            return null;
        }
        String upper = type.trim().toUpperCase();
        if (allModules().contains(upper)) {
            return upper;
        }
        return null;
    }

    private static final String TS_RANGE = "(CAST(:from AS timestamptz) IS NULL OR {ts} >= :from) AND (CAST(:to AS timestamptz) IS NULL OR {ts} <= :to)";

    private String tsRange(String tsExpr) {
        return TS_RANGE.replace("{ts}", tsExpr);
    }

    private String plannerTask() {
        return """
                SELECT 'PLANNER'::text AS module, 'TASK'::text AS result_type, t.id AS id,
                       t.title::text AS title, COALESCE(t.description, '')::text AS subtitle,
                       (t.created_at AT TIME ZONE 'UTC') AS ts
                FROM planner_task t
                WHERE t.user_id = :userId
                  AND (LOWER(t.title) LIKE LOWER(:term) OR LOWER(COALESCE(t.description, '')) LIKE LOWER(:term))
                  AND """ + tsRange("(t.created_at AT TIME ZONE 'UTC')");
    }

    private String plannerTaskList() {
        return """
                SELECT 'PLANNER'::text AS module, 'TASK_LIST'::text AS result_type, tl.id AS id,
                       tl.name::text AS title, COALESCE(tl.description, '')::text AS subtitle,
                       (tl.created_at AT TIME ZONE 'UTC') AS ts
                FROM planner_task_list tl
                WHERE tl.user_id = :userId
                  AND (LOWER(tl.name) LIKE LOWER(:term) OR LOWER(COALESCE(tl.description, '')) LIKE LOWER(:term))
                  AND """ + tsRange("(tl.created_at AT TIME ZONE 'UTC')");
    }

    private String plannerEvent() {
        return """
                SELECT 'PLANNER'::text AS module, 'PLANNER_EVENT'::text AS result_type, e.id AS id,
                       e.title::text AS title,
                       COALESCE(NULLIF(e.location, ''), NULLIF(e.description, ''), '')::text AS subtitle,
                       e.start_at AS ts
                FROM planner_event e
                WHERE e.user_id = :userId
                  AND (LOWER(e.title) LIKE LOWER(:term)
                       OR LOWER(COALESCE(e.description, '')) LIKE LOWER(:term)
                       OR LOWER(COALESCE(e.location, '')) LIKE LOWER(:term))
                  AND """ + tsRange("e.start_at");
    }

    private String medicine() {
        return """
                SELECT 'MEDICINES'::text AS module, 'MEDICINE'::text AS result_type, m.id AS id,
                       m.name::text AS title,
                       COALESCE(NULLIF(m.generic_name, ''), m.notes, '')::text AS subtitle,
                       (m.created_at AT TIME ZONE 'UTC') AS ts
                FROM medicines m
                WHERE m.user_id = :userId
                  AND (LOWER(m.name) LIKE LOWER(:term)
                       OR LOWER(COALESCE(m.generic_name, '')) LIKE LOWER(:term)
                       OR LOWER(COALESCE(m.notes, '')) LIKE LOWER(:term))
                  AND """ + tsRange("(m.created_at AT TIME ZONE 'UTC')");
    }

    private String healthEvent() {
        return """
                SELECT 'HEALTH'::text AS module, 'HEALTH_EVENT'::text AS result_type, h.id AS id,
                       h.title::text AS title, h.type::text AS subtitle, h.occurred_at AS ts
                FROM health_events h
                WHERE h.user_id = :userId
                  AND (LOWER(h.title) LIKE LOWER(:term) OR LOWER(COALESCE(h.notes, '')) LIKE LOWER(:term))
                  AND """ + tsRange("h.occurred_at");
    }

    private String healthAppointment() {
        return """
                SELECT 'HEALTH'::text AS module, 'HEALTH_APPOINTMENT'::text AS result_type, a.id AS id,
                       a.title::text AS title,
                       COALESCE(NULLIF(a.location, ''), a.status, '')::text AS subtitle,
                       a.scheduled_at AS ts
                FROM health_appointments a
                WHERE a.user_id = :userId
                  AND (LOWER(a.title) LIKE LOWER(:term)
                       OR LOWER(COALESCE(a.location, '')) LIKE LOWER(:term)
                       OR LOWER(COALESCE(a.notes, '')) LIKE LOWER(:term))
                  AND """ + tsRange("a.scheduled_at");
    }

    private String healthSymptomLog() {
        return """
                SELECT 'HEALTH'::text AS module, 'SYMPTOM_LOG'::text AS result_type, s.id AS id,
                       s.title::text AS title, COALESCE(s.severity, '')::text AS subtitle,
                       s.observed_at AS ts
                FROM health_symptom_logs s
                WHERE s.user_id = :userId
                  AND (LOWER(s.title) LIKE LOWER(:term)
                       OR LOWER(COALESCE(s.description, '')) LIKE LOWER(:term)
                       OR LOWER(COALESCE(s.notes, '')) LIKE LOWER(:term))
                  AND """ + tsRange("s.observed_at");
    }

    private String healthActivity() {
        return """
                SELECT 'HEALTH'::text AS module, 'HEALTH_ACTIVITY'::text AS result_type, act.id AS id,
                       act.type::text AS title, COALESCE(act.notes, '')::text AS subtitle,
                       act.performed_at AS ts
                FROM health_activities act
                WHERE act.user_id = :userId
                  AND (LOWER(act.type) LIKE LOWER(:term) OR LOWER(COALESCE(act.notes, '')) LIKE LOWER(:term))
                  AND """ + tsRange("act.performed_at");
    }

    private String healthMeasurement() {
        return """
                SELECT 'HEALTH'::text AS module, 'HEALTH_MEASUREMENT'::text AS result_type, hm.id AS id,
                       hm.type::text AS title,
                       (hm.value::text || ' ' || hm.unit)::text AS subtitle,
                       hm.measured_at AS ts
                FROM health_measurements hm
                WHERE hm.user_id = :userId
                  AND (LOWER(hm.type) LIKE LOWER(:term)
                       OR LOWER(COALESCE(hm.notes, '')) LIKE LOWER(:term)
                       OR LOWER(COALESCE(hm.source, '')) LIKE LOWER(:term))
                  AND """ + tsRange("hm.measured_at");
    }

    private String healthSleepRecord() {
        return """
                SELECT 'HEALTH'::text AS module, 'SLEEP_RECORD'::text AS result_type, r.id AS id,
                       'Sleep'::text AS title, COALESCE(r.notes, '')::text AS subtitle,
                       r.started_at AS ts
                FROM health_sleep_records r
                WHERE r.user_id = :userId
                  AND LOWER(COALESCE(r.notes, '')) LIKE LOWER(:term)
                  AND """ + tsRange("r.started_at");
    }

    private String meal() {
        return """
                SELECT 'DIET'::text AS module, 'MEAL'::text AS result_type, m.id AS id,
                       m.title::text AS title, m.meal_type::text AS subtitle, m.consumed_at AS ts
                FROM meals m
                WHERE m.user_id = :userId
                  AND (LOWER(m.title) LIKE LOWER(:term) OR LOWER(COALESCE(m.notes, '')) LIKE LOWER(:term))
                  AND """ + tsRange("m.consumed_at");
    }

    private String mealItem() {
        return """
                SELECT 'DIET'::text AS module, 'MEAL_ITEM'::text AS result_type, mi.id AS id,
                       mi.name::text AS title, COALESCE(mi.notes, '')::text AS subtitle,
                       (mi.created_at AT TIME ZONE 'UTC') AS ts
                FROM meal_items mi
                JOIN meals m ON m.id = mi.meal_id
                WHERE m.user_id = :userId
                  AND (LOWER(mi.name) LIKE LOWER(:term) OR LOWER(COALESCE(mi.notes, '')) LIKE LOWER(:term))
                  AND """ + tsRange("(mi.created_at AT TIME ZONE 'UTC')");
    }

    private String dietProfile() {
        return """
                SELECT 'DIET'::text AS module, 'DIET_PROFILE'::text AS result_type, dp.id AS id,
                       'Diet Profile'::text AS title,
                       COALESCE(NULLIF(dp.dietary_preference, ''), NULLIF(dp.custom_preference, ''), '')::text AS subtitle,
                       (dp.created_at AT TIME ZONE 'UTC') AS ts
                FROM diet_profiles dp
                WHERE dp.user_id = :userId
                  AND (LOWER(COALESCE(dp.dietary_preference, '')) LIKE LOWER(:term)
                       OR LOWER(COALESCE(dp.custom_preference, '')) LIKE LOWER(:term)
                       OR LOWER(COALESCE(dp.disliked_foods, '')) LIKE LOWER(:term)
                       OR LOWER(COALESCE(dp.notes, '')) LIKE LOWER(:term))
                  AND """ + tsRange("(dp.created_at AT TIME ZONE 'UTC')");
    }

    private String waterIntake() {
        return """
                SELECT 'DIET'::text AS module, 'WATER_INTAKE'::text AS result_type, w.id AS id,
                       'Water Intake'::text AS title,
                       (w.amount::text || ' ' || w.unit)::text AS subtitle,
                       w.consumed_at AS ts
                FROM water_intake w
                WHERE w.user_id = :userId
                  AND LOWER(w.unit) LIKE LOWER(:term)
                  AND """ + tsRange("w.consumed_at");
    }

    private String habit() {
        return """
                SELECT 'HABITS'::text AS module, 'HABIT'::text AS result_type, h.id AS id,
                       h.name::text AS title, COALESCE(h.description, '')::text AS subtitle,
                       (h.created_at AT TIME ZONE 'UTC') AS ts
                FROM habits h
                WHERE h.user_id = :userId
                  AND (LOWER(h.name) LIKE LOWER(:term) OR LOWER(COALESCE(h.description, '')) LIKE LOWER(:term))
                  AND """ + tsRange("(h.created_at AT TIME ZONE 'UTC')");
    }

    private String financeAccount() {
        return """
                SELECT 'FINANCE'::text AS module, 'ACCOUNT'::text AS result_type, fa.id AS id,
                       fa.name::text AS title, COALESCE(fa.notes, '')::text AS subtitle,
                       (fa.created_at AT TIME ZONE 'UTC') AS ts
                FROM finance_accounts fa
                WHERE fa.user_id = :userId
                  AND (LOWER(fa.name) LIKE LOWER(:term) OR LOWER(COALESCE(fa.notes, '')) LIKE LOWER(:term))
                  AND """ + tsRange("(fa.created_at AT TIME ZONE 'UTC')");
    }

    private String financeCategory() {
        return """
                SELECT 'FINANCE'::text AS module, 'CATEGORY'::text AS result_type, fc.id AS id,
                       fc.name::text AS title, fc.type::text AS subtitle,
                       (fc.created_at AT TIME ZONE 'UTC') AS ts
                FROM finance_categories fc
                WHERE fc.user_id = :userId
                  AND LOWER(fc.name) LIKE LOWER(:term)
                  AND """ + tsRange("(fc.created_at AT TIME ZONE 'UTC')");
    }

    private String financeTransaction() {
        return """
                SELECT 'FINANCE'::text AS module, 'TRANSACTION'::text AS result_type, ft.id AS id,
                       COALESCE(NULLIF(ft.description, ''), ft.type)::text AS title,
                       ''::text AS subtitle,
                       (ft.occurred_at AT TIME ZONE 'UTC') AS ts
                FROM finance_transactions ft
                WHERE ft.user_id = :userId
                  AND (LOWER(COALESCE(ft.description, '')) LIKE LOWER(:term)
                       OR LOWER(COALESCE(ft.notes, '')) LIKE LOWER(:term)
                       OR LOWER(ft.type) LIKE LOWER(:term))
                  AND """ + tsRange("(ft.occurred_at AT TIME ZONE 'UTC')");
    }

    private String financeTransfer() {
        return """
                SELECT 'FINANCE'::text AS module, 'TRANSFER'::text AS result_type, tf.id AS id,
                       'Transfer'::text AS title, COALESCE(tf.note, '')::text AS subtitle,
                       (tf.transferred_at AT TIME ZONE 'UTC') AS ts
                FROM finance_transfers tf
                WHERE tf.user_id = :userId
                  AND (LOWER(COALESCE(tf.note, '')) LIKE LOWER(:term)
                       OR LOWER(COALESCE(tf.currency, '')) LIKE LOWER(:term))
                  AND """ + tsRange("(tf.transferred_at AT TIME ZONE 'UTC')");
    }

    private String document() {
        return """
                SELECT 'DOCUMENTS'::text AS module, 'DOCUMENT'::text AS result_type, d.id AS id,
                       d.original_filename::text AS title, d.category::text AS subtitle,
                       (d.created_at AT TIME ZONE 'UTC') AS ts
                FROM documents d
                WHERE d.user_id = :userId
                  AND (LOWER(d.original_filename) LIKE LOWER(:term)
                       OR LOWER(COALESCE(d.description, '')) LIKE LOWER(:term)
                       OR LOWER(d.category) LIKE LOWER(:term)
                       OR LOWER(d.content_type) LIKE LOWER(:term))
                  AND """ + tsRange("(d.created_at AT TIME ZONE 'UTC')");
    }
}