-- V030__Planner_schema.sql
-- Planner module schema for Blistra backend.
--
-- Scope: tasks, task lists/categories, and simple time-blocked events.
-- All Planner resources are owned by a user (referenced by users.id).
--
-- Design notes:
--  * A task's user-facing due fields are due_date/due_time; due_at is the
--    derived instant (resolved in the configurable user timezone) used for
--    today/upcoming/overdue queries. Overdue itself is never stored.
--  * Deleting a task list unassigns its tasks (list_id -> NULL), it does not
--    delete them.
--  * Recurrence engines, notifications, external calendar sync and
--    cross-module "today" aggregation are deliberately out of Planner scope.

-- ---------------------------------------------------------------------------
-- Task lists (optional categories used to organise tasks)
-- ---------------------------------------------------------------------------
CREATE TABLE planner_task_list (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    name VARCHAR(100) NOT NULL,
    description VARCHAR(500),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT planner_task_list_user_fk FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT planner_task_list_user_name_unique UNIQUE (user_id, name),
    CONSTRAINT planner_task_list_name_not_empty CHECK (name <> '')
);

CREATE INDEX idx_planner_task_list_user ON planner_task_list(user_id);

CREATE TRIGGER planner_task_list_updated_at_trigger
BEFORE UPDATE ON planner_task_list
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- ---------------------------------------------------------------------------
-- Tasks
-- ---------------------------------------------------------------------------
CREATE TABLE planner_task (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    list_id UUID,
    title VARCHAR(200) NOT NULL,
    description VARCHAR(2000),
    status VARCHAR(20) NOT NULL DEFAULT 'TODO',
    priority VARCHAR(10) NOT NULL DEFAULT 'MEDIUM',
    due_date DATE,
    due_time TIME,
    due_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT planner_task_user_fk FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT planner_task_list_fk FOREIGN KEY (list_id)
        REFERENCES planner_task_list(id) ON DELETE SET NULL,
    CONSTRAINT planner_task_title_not_empty CHECK (title <> ''),
    CONSTRAINT planner_task_status_valid CHECK (status IN ('TODO', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED')),
    CONSTRAINT planner_task_priority_valid CHECK (priority IN ('LOW', 'MEDIUM', 'HIGH')),
    CONSTRAINT planner_task_time_requires_date CHECK (due_time IS NULL OR due_date IS NOT NULL),
    CONSTRAINT planner_task_completed_at_invariant CHECK (completed_at IS NULL OR status = 'COMPLETED')
);

-- Frequently used access paths: per-user listing/filtering, day-scoped queries
-- (today / overdue / upcoming) and list detach on list deletion.
CREATE INDEX idx_planner_task_user ON planner_task(user_id);
CREATE INDEX idx_planner_task_user_status ON planner_task(user_id, status);
CREATE INDEX idx_planner_task_user_due_at ON planner_task(user_id, due_at);
CREATE INDEX idx_planner_task_list ON planner_task(list_id);

CREATE TRIGGER planner_task_updated_at_trigger
BEFORE UPDATE ON planner_task
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- ---------------------------------------------------------------------------
-- Events (simple time-blocked slots; no recurrence in V1)
-- ---------------------------------------------------------------------------
CREATE TABLE planner_event (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    title VARCHAR(200) NOT NULL,
    description VARCHAR(2000),
    location VARCHAR(255),
    start_at TIMESTAMPTZ NOT NULL,
    end_at TIMESTAMPTZ NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'SCHEDULED',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT planner_event_user_fk FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT planner_event_title_not_empty CHECK (title <> ''),
    CONSTRAINT planner_event_status_valid CHECK (status IN ('SCHEDULED', 'COMPLETED', 'CANCELLED')),
    CONSTRAINT planner_event_range_valid CHECK (end_at > start_at)
);

CREATE INDEX idx_planner_event_user_start ON planner_event(user_id, start_at);
CREATE INDEX idx_planner_event_user_status ON planner_event(user_id, status);

CREATE TRIGGER planner_event_updated_at_trigger
BEFORE UPDATE ON planner_event
FOR EACH ROW EXECUTE FUNCTION update_timestamp();