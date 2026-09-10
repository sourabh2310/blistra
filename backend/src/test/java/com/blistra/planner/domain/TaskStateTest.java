package com.blistra.planner.domain;

import com.blistra.common.exception.InvalidStateException;
import org.junit.jupiter.api.Test;

import java.time.OffsetDateTime;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class TaskStateTest {

    private Task task() {
        return new Task();
    }

    @Test
    void newTaskIsTodoAndMediumPriority() {
        Task task = new Task();
        assertThat(task.getStatus()).isEqualTo(TaskStatus.TODO);
        assertThat(task.isActive()).isTrue();
    }

    @Test
    void todoCanMoveToInProgressCompletedAndCancelled() {
        assertThatThrownBy(() -> task().changeStatus(TaskStatus.CANCELLED, now())).doesNotThrowAnyException();

        assertThatThrownBy(() -> task().changeStatus(TaskStatus.COMPLETED, now())).doesNotThrowAnyException();

        assertThatThrownBy(() -> task().changeStatus(TaskStatus.IN_PROGRESS, now())).doesNotThrowAnyException();
    }

    @Test
    void completingRecordsCompletedAt() {
        Task task = task();
        task.changeStatus(TaskStatus.COMPLETED, OffsetDateTime.parse("2026-01-01T10:00:00+05:30"));

        assertThat(task.getStatus()).isEqualTo(TaskStatus.COMPLETED);
        assertThat(task.getCompletedAt()).isEqualTo(OffsetDateTime.parse("2026-01-01T10:00:00+05:30"));
        assertThat(task.isActive()).isFalse();
    }

    @Test
    void leavingCompletedClearsCompletedAt() {
        Task task = task();
        task.changeStatus(TaskStatus.COMPLETED, now());
        task.changeStatus(TaskStatus.TODO, now());

        assertThat(task.getStatus()).isEqualTo(TaskStatus.TODO);
        assertThat(task.getCompletedAt()).isNull();
    }

    @Test
    void completedCannotMoveToCancelledOrInProgress() {
        Task completed = task();
        completed.changeStatus(TaskStatus.COMPLETED, now());

        assertThatThrownBy(() -> completed.changeStatus(TaskStatus.CANCELLED, now()))
                .isInstanceOf(InvalidStateException.class);
        assertThatThrownBy(() -> completed.changeStatus(TaskStatus.IN_PROGRESS, now()))
                .isInstanceOf(InvalidStateException.class);
    }

    @Test
    void cancelledCanOnlyReopenToTodo() {
        Task cancelled = task();
        cancelled.changeStatus(TaskStatus.CANCELLED, now());

        cancelled.changeStatus(TaskStatus.TODO, now());
        assertThat(cancelled.getStatus()).isEqualTo(TaskStatus.TODO);

        Task cancelledAgain = task();
        cancelledAgain.changeStatus(TaskStatus.CANCELLED, now());
        assertThatThrownBy(() -> cancelledAgain.changeStatus(TaskStatus.COMPLETED, now()))
                .isInstanceOf(InvalidStateException.class);
    }

    @Test
    void sameStatusAndNullTargetAreNoOps() {
        Task task = task();
        task.changeStatus(TaskStatus.TODO, now());
        assertThat(task.getStatus()).isEqualTo(TaskStatus.TODO);

        Task task2 = task();
        task2.changeStatus(null, now());
        assertThat(task2.getStatus()).isEqualTo(TaskStatus.TODO);
    }

    @Test
    void inProgressCanReturnToTodoAndBeCancelled() {
        Task task = task();
        task.changeStatus(TaskStatus.IN_PROGRESS, now());
        task.changeStatus(TaskStatus.TODO, now());
        assertThat(task.getStatus()).isEqualTo(TaskStatus.TODO);

        Task task2 = task();
        task2.changeStatus(TaskStatus.IN_PROGRESS, now());
        task2.changeStatus(TaskStatus.CANCELLED, now());
        assertThat(task2.getStatus()).isEqualTo(TaskStatus.CANCELLED);
    }

    private OffsetDateTime now() {
        return OffsetDateTime.now();
    }
}