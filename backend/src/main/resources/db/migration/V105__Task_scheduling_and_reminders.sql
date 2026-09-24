-- Task scheduled blocks and domain-owned reminder policy.
ALTER TABLE planner_task
    ADD COLUMN start_at TIMESTAMPTZ,
    ADD COLUMN end_at TIMESTAMPTZ,
    ADD COLUMN reminder_mode VARCHAR(24) NOT NULL DEFAULT 'NONE';

ALTER TABLE planner_task
    ADD CONSTRAINT planner_task_block_range_valid
        CHECK (end_at IS NULL OR (start_at IS NOT NULL AND end_at > start_at)),
    ADD CONSTRAINT planner_task_reminder_mode_valid
        CHECK (reminder_mode IN ('NONE', 'AT_START', 'AT_END', 'AT_START_AND_END'));

CREATE INDEX idx_planner_task_user_start_at ON planner_task(user_id, start_at);
CREATE INDEX idx_planner_task_user_end_at ON planner_task(user_id, end_at);
