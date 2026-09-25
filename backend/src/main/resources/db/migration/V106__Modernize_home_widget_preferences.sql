ALTER TABLE user_app_preferences
    ALTER COLUMN home_widgets SET DEFAULT 'TODAY_OVERVIEW,TODAYS_SCHEDULE,NEEDS_ATTENTION,YOUR_LIFE,THIS_WEEK,HEALTH,MEDICINES,DIET,HABITS,FINANCE',
    ALTER COLUMN bottom_nav SET DEFAULT 'HOME,PLANNER,ADD,HUB,HEALTH';

UPDATE user_app_preferences
SET home_widgets = 'TODAY_OVERVIEW,TODAYS_SCHEDULE,NEEDS_ATTENTION,YOUR_LIFE,THIS_WEEK,HEALTH,MEDICINES,DIET,HABITS,FINANCE'
WHERE BTRIM(home_widgets) = 'DAY_AT_A_GLANCE,HEALTH,MEDICINES,DIET,HABITS,PLANNER,FINANCE';

WITH tokens AS (
    SELECT preferences.user_id,
           token.ordinal,
           CASE BTRIM(UPPER(token.value))
               WHEN 'DAY_AT_A_GLANCE' THEN 'TODAY_OVERVIEW'
               WHEN 'PLANNER' THEN 'TODAYS_SCHEDULE'
               WHEN 'TODAY_OVERVIEW' THEN 'TODAY_OVERVIEW'
               WHEN 'TODAYS_SCHEDULE' THEN 'TODAYS_SCHEDULE'
               WHEN 'NEEDS_ATTENTION' THEN 'NEEDS_ATTENTION'
               WHEN 'YOUR_LIFE' THEN 'YOUR_LIFE'
               WHEN 'THIS_WEEK' THEN 'THIS_WEEK'
               WHEN 'HEALTH' THEN 'HEALTH'
               WHEN 'MEDICINES' THEN 'MEDICINES'
               WHEN 'DIET' THEN 'DIET'
               WHEN 'HABITS' THEN 'HABITS'
               WHEN 'FINANCE' THEN 'FINANCE'
           END AS mapped_token
    FROM user_app_preferences preferences
    CROSS JOIN LATERAL regexp_split_to_table(preferences.home_widgets, ',')
        WITH ORDINALITY AS token(value, ordinal)
),
mapped AS (
    SELECT user_id,
           mapped_token,
           MIN(ordinal) AS first_ordinal
    FROM tokens
    WHERE mapped_token IS NOT NULL
    GROUP BY user_id, mapped_token
),
aggregated AS (
    SELECT user_id,
           STRING_AGG(mapped_token, ',' ORDER BY first_ordinal) AS mapped_widgets
    FROM mapped
    GROUP BY user_id
),
with_life_section AS (
    SELECT user_id,
           CASE
               WHEN mapped_widgets !~ '(^|,)YOUR_LIFE(,|$)'
                    AND (mapped_widgets ~ '^(HEALTH|MEDICINES|DIET|HABITS|FINANCE)(,|$)'
                         OR mapped_widgets ~ ',(HEALTH|MEDICINES|DIET|HABITS|FINANCE)(,|$)')
                   THEN REGEXP_REPLACE(mapped_widgets,
                       '(^|,)(HEALTH|MEDICINES|DIET|HABITS|FINANCE)', '\1YOUR_LIFE,\2')
               ELSE mapped_widgets
           END AS mapped_widgets
    FROM aggregated
)
UPDATE user_app_preferences preferences
SET home_widgets = COALESCE(
        CASE
            WHEN with_life_section.mapped_widgets = ''
                THEN 'TODAY_OVERVIEW,TODAYS_SCHEDULE,NEEDS_ATTENTION,YOUR_LIFE,THIS_WEEK,HEALTH,MEDICINES,DIET,HABITS,FINANCE'
            ELSE with_life_section.mapped_widgets
        END,
        'TODAY_OVERVIEW,TODAYS_SCHEDULE,NEEDS_ATTENTION,YOUR_LIFE,THIS_WEEK,HEALTH,MEDICINES,DIET,HABITS,FINANCE'
    )
FROM with_life_section
WHERE preferences.user_id = with_life_section.user_id
  AND BTRIM(preferences.home_widgets) <> 'DAY_AT_A_GLANCE,HEALTH,MEDICINES,DIET,HABITS,PLANNER,FINANCE';
