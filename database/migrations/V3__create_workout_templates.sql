CREATE TABLE workout_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    owner_user_id UUID NOT NULL,

    name VARCHAR(200) NOT NULL,
    description TEXT,

    is_archived BOOLEAN NOT NULL DEFAULT FALSE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_workout_templates_owner
        FOREIGN KEY (owner_user_id)
        REFERENCES users (id)
        ON DELETE RESTRICT,

    CONSTRAINT ck_workout_templates_name
        CHECK (btrim(name) <> ''),

    CONSTRAINT ck_workout_templates_timestamps
        CHECK (updated_at >= created_at)
);

CREATE INDEX ix_workout_templates_owner
    ON workout_templates (owner_user_id);


CREATE TABLE workout_template_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    template_id UUID NOT NULL,
    based_on_version_id UUID,

    version_number INTEGER NOT NULL,

    status VARCHAR(20) NOT NULL DEFAULT 'DRAFT',
    change_summary TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    published_at TIMESTAMPTZ,

    CONSTRAINT fk_template_versions_template
        FOREIGN KEY (template_id)
        REFERENCES workout_templates (id)
        ON DELETE RESTRICT,

    CONSTRAINT uq_template_versions_number
        UNIQUE (template_id, version_number),

    CONSTRAINT uq_template_versions_id_template
        UNIQUE (id, template_id),

    CONSTRAINT fk_template_versions_based_on
        FOREIGN KEY (based_on_version_id, template_id)
        REFERENCES workout_template_versions (id, template_id)
        ON DELETE RESTRICT,

    CONSTRAINT ck_template_versions_number
        CHECK (version_number > 0),

    CONSTRAINT ck_template_versions_not_self
        CHECK (
            based_on_version_id IS NULL
            OR based_on_version_id <> id
        ),

    CONSTRAINT ck_template_versions_status
        CHECK (
            (
                status = 'DRAFT'
                AND published_at IS NULL
            )
            OR
            (
                status = 'PUBLISHED'
                AND published_at IS NOT NULL
            )
        ),

    CONSTRAINT ck_template_versions_publication_time
        CHECK (
            published_at IS NULL
            OR published_at >= created_at
        )
);

CREATE INDEX ix_template_versions_based_on
    ON workout_template_versions (based_on_version_id);


CREATE TABLE template_exercises (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    template_version_id UUID NOT NULL,
    exercise_id UUID NOT NULL,

    position INTEGER NOT NULL,

    notes TEXT,
    default_rest_seconds INTEGER,

    CONSTRAINT fk_template_exercises_version
        FOREIGN KEY (template_version_id)
        REFERENCES workout_template_versions (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_template_exercises_exercise
        FOREIGN KEY (exercise_id)
        REFERENCES exercises (id)
        ON DELETE RESTRICT,

    CONSTRAINT uq_template_exercises_position
        UNIQUE (template_version_id, position)
        DEFERRABLE INITIALLY IMMEDIATE,

    CONSTRAINT ck_template_exercises_position
        CHECK (position > 0),

    CONSTRAINT ck_template_exercises_rest
        CHECK (default_rest_seconds >= 0)
);

CREATE INDEX ix_template_exercises_exercise
    ON template_exercises (exercise_id);


CREATE TABLE template_sets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    template_exercise_id UUID NOT NULL,

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

    rest_after_seconds INTEGER,
    notes TEXT,

    CONSTRAINT fk_template_sets_exercise
        FOREIGN KEY (template_exercise_id)
        REFERENCES template_exercises (id)
        ON DELETE RESTRICT,

    CONSTRAINT uq_template_sets_position
        UNIQUE (template_exercise_id, position)
        DEFERRABLE INITIALLY IMMEDIATE,

    CONSTRAINT ck_template_sets_position
        CHECK (position > 0),

    CONSTRAINT ck_template_sets_category
        CHECK (set_category IN ('WARMUP', 'WORKING')),

    CONSTRAINT ck_template_sets_effort
        CHECK (effort_mode IN ('NORMAL', 'FAILURE', 'AMRAP')),

    CONSTRAINT ck_template_sets_weight
        CHECK (target_weight_kg >= 0),

    CONSTRAINT ck_template_sets_assistance
        CHECK (target_assistance_kg >= 0),

    CONSTRAINT ck_template_sets_load_exclusive
        CHECK (
            target_weight_kg IS NULL
            OR target_assistance_kg IS NULL
        ),

    CONSTRAINT ck_template_sets_reps
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

    CONSTRAINT ck_template_sets_duration
        CHECK (target_duration_seconds > 0),

    CONSTRAINT ck_template_sets_distance
        CHECK (target_distance_meters > 0),

    CONSTRAINT ck_template_sets_rpe
        CHECK (target_rpe BETWEEN 1 AND 10),

    CONSTRAINT ck_template_sets_rir
        CHECK (target_rir BETWEEN 0 AND 10),

    CONSTRAINT ck_template_sets_rest
        CHECK (rest_after_seconds >= 0)
);