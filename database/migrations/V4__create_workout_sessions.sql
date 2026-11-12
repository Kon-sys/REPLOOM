CREATE TABLE workout_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL,
    template_version_id UUID,

    client_operation_id UUID NOT NULL,

    name_snapshot VARCHAR(200) NOT NULL,

    status VARCHAR(20) NOT NULL DEFAULT 'IN_PROGRESS',

    started_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    finished_at TIMESTAMPTZ,

    timezone VARCHAR(100) NOT NULL DEFAULT 'Europe/Moscow',

    revision BIGINT NOT NULL DEFAULT 1,
    notes TEXT,

    CONSTRAINT fk_workout_sessions_user
        FOREIGN KEY (user_id)
        REFERENCES users (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_workout_sessions_template_version
        FOREIGN KEY (template_version_id)
        REFERENCES workout_template_versions (id)
        ON DELETE RESTRICT,

    CONSTRAINT uq_workout_sessions_start_operation
        UNIQUE (user_id, client_operation_id),

    CONSTRAINT ck_workout_sessions_name
        CHECK (btrim(name_snapshot) <> ''),

    CONSTRAINT ck_workout_sessions_timezone
        CHECK (btrim(timezone) <> ''),

    CONSTRAINT ck_workout_sessions_revision
        CHECK (revision > 0),

    CONSTRAINT ck_workout_sessions_status_time
        CHECK (
            (
                status IN ('IN_PROGRESS', 'PAUSED')
                AND finished_at IS NULL
            )
            OR
            (
                status IN ('COMPLETED', 'DISCARDED')
                AND finished_at IS NOT NULL
                AND finished_at >= started_at
            )
        )
);

CREATE UNIQUE INDEX uq_workout_sessions_one_active
    ON workout_sessions (user_id)
    WHERE status IN ('IN_PROGRESS', 'PAUSED');

CREATE INDEX ix_workout_sessions_user_started
    ON workout_sessions (user_id, started_at DESC);

CREATE INDEX ix_workout_sessions_template_version
    ON workout_sessions (template_version_id);


CREATE TABLE session_exercises (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    session_id UUID NOT NULL,
    exercise_id UUID NOT NULL,

    original_exercise_id UUID,

    name_snapshot VARCHAR(200) NOT NULL,
    measurement_type_snapshot VARCHAR(30) NOT NULL,
    load_basis_snapshot VARCHAR(30),

    position INTEGER NOT NULL,
    notes TEXT,

    CONSTRAINT fk_session_exercises_session
        FOREIGN KEY (session_id)
        REFERENCES workout_sessions (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_session_exercises_exercise
        FOREIGN KEY (exercise_id)
        REFERENCES exercises (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_session_exercises_original
        FOREIGN KEY (original_exercise_id)
        REFERENCES exercises (id)
        ON DELETE RESTRICT,

    CONSTRAINT uq_session_exercises_position
        UNIQUE (session_id, position)
        DEFERRABLE INITIALLY IMMEDIATE,

    CONSTRAINT ck_session_exercises_position
        CHECK (position > 0),

    CONSTRAINT ck_session_exercises_name
        CHECK (btrim(name_snapshot) <> ''),

    CONSTRAINT ck_session_exercises_measurement
        CHECK (
            measurement_type_snapshot IN (
                'WEIGHT_REPS',
                'BODYWEIGHT_REPS',
                'ASSISTED_REPS',
                'TIME',
                'DISTANCE_TIME',
                'REPS_ONLY',
                'WEIGHT_TIME'
            )
        ),

    CONSTRAINT ck_session_exercises_load_basis
        CHECK (
            load_basis_snapshot IS NULL
            OR load_basis_snapshot IN (
                'ONE_IMPLEMENT',
                'TOTAL',
                'EXTERNAL'
            )
        )
);

CREATE INDEX ix_session_exercises_exercise
    ON session_exercises (exercise_id);

CREATE INDEX ix_session_exercises_original
    ON session_exercises (original_exercise_id);


CREATE TABLE session_sets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    session_exercise_id UUID NOT NULL,

    position INTEGER NOT NULL,

    set_category VARCHAR(20) NOT NULL DEFAULT 'WORKING',
    effort_mode VARCHAR(20) NOT NULL DEFAULT 'NORMAL',

    target_weight_kg NUMERIC(10, 3),
    target_assistance_kg NUMERIC(10, 3),

    target_reps_min INTEGER,
    target_reps_max INTEGER,

    target_duration_seconds NUMERIC(12, 3),
    target_distance_meters NUMERIC(14, 3),

    target_rpe NUMERIC(3, 1),
    target_rir NUMERIC(3, 1),

    actual_weight_kg NUMERIC(10, 3),
    actual_assistance_kg NUMERIC(10, 3),

    actual_reps INTEGER,

    actual_duration_seconds NUMERIC(12, 3),
    actual_distance_meters NUMERIC(14, 3),

    actual_rpe NUMERIC(3, 1),
    actual_rir NUMERIC(3, 1),

    rest_after_seconds INTEGER,

    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    completed_at TIMESTAMPTZ,

    notes TEXT,

    CONSTRAINT fk_session_sets_exercise
        FOREIGN KEY (session_exercise_id)
        REFERENCES session_exercises (id)
        ON DELETE RESTRICT,

    CONSTRAINT uq_session_sets_position
        UNIQUE (session_exercise_id, position)
        DEFERRABLE INITIALLY IMMEDIATE,

    CONSTRAINT ck_session_sets_position
        CHECK (position > 0),

    CONSTRAINT ck_session_sets_category
        CHECK (set_category IN ('WARMUP', 'WORKING')),

    CONSTRAINT ck_session_sets_effort
        CHECK (effort_mode IN ('NORMAL', 'FAILURE', 'AMRAP')),

    CONSTRAINT ck_session_sets_target_weight
        CHECK (target_weight_kg >= 0),

    CONSTRAINT ck_session_sets_target_assistance
        CHECK (target_assistance_kg >= 0),

    CONSTRAINT ck_session_sets_target_load_exclusive
        CHECK (
            target_weight_kg IS NULL
            OR target_assistance_kg IS NULL
        ),

    CONSTRAINT ck_session_sets_target_reps
        CHECK (
            (
                target_reps_min IS NULL
                AND target_reps_max IS NULL
            )
            OR
            (
                target_reps_min IS NOT NULL
                AND target_reps_max IS NOT NULL
                AND target_reps_min >= 1
                AND target_reps_max >= target_reps_min
            )
        ),

    CONSTRAINT ck_session_sets_target_duration
        CHECK (target_duration_seconds > 0),

    CONSTRAINT ck_session_sets_target_distance
        CHECK (target_distance_meters > 0),

    CONSTRAINT ck_session_sets_target_rpe
        CHECK (target_rpe BETWEEN 1 AND 10),

    CONSTRAINT ck_session_sets_target_rir
        CHECK (target_rir BETWEEN 0 AND 10),

    CONSTRAINT ck_session_sets_actual_weight
        CHECK (actual_weight_kg >= 0),

    CONSTRAINT ck_session_sets_actual_assistance
        CHECK (actual_assistance_kg >= 0),

    CONSTRAINT ck_session_sets_actual_load_exclusive
        CHECK (
            actual_weight_kg IS NULL
            OR actual_assistance_kg IS NULL
        ),

    CONSTRAINT ck_session_sets_actual_reps
        CHECK (actual_reps >= 1),

    CONSTRAINT ck_session_sets_actual_duration
        CHECK (actual_duration_seconds > 0),

    CONSTRAINT ck_session_sets_actual_distance
        CHECK (actual_distance_meters > 0),

    CONSTRAINT ck_session_sets_actual_rpe
        CHECK (actual_rpe BETWEEN 1 AND 10),

    CONSTRAINT ck_session_sets_actual_rir
        CHECK (actual_rir BETWEEN 0 AND 10),

    CONSTRAINT ck_session_sets_rest
        CHECK (rest_after_seconds >= 0),

    CONSTRAINT ck_session_sets_status_time
        CHECK (
            (
                status IN ('PENDING', 'SKIPPED')
                AND completed_at IS NULL
            )
            OR
            (
                status = 'COMPLETED'
                AND completed_at IS NOT NULL
            )
        ),

    CONSTRAINT ck_session_sets_completed_has_result
        CHECK (
            status <> 'COMPLETED'
            OR actual_reps IS NOT NULL
            OR actual_duration_seconds IS NOT NULL
            OR actual_distance_meters IS NOT NULL
        )
);