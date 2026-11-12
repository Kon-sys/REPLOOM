CREATE TABLE muscle_groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    parent_id UUID,

    name VARCHAR(150) NOT NULL,
    description TEXT,

    sort_order INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT fk_muscle_groups_parent
        FOREIGN KEY (parent_id)
        REFERENCES muscle_groups (id)
        ON DELETE RESTRICT,

    CONSTRAINT ck_muscle_groups_not_self_parent
        CHECK (parent_id IS NULL OR parent_id <> id),

    CONSTRAINT ck_muscle_groups_name
        CHECK (btrim(name) <> ''),

    CONSTRAINT ck_muscle_groups_sort_order
        CHECK (sort_order >= 0)
);

CREATE INDEX ix_muscle_groups_parent
    ON muscle_groups (parent_id);


CREATE TABLE equipment (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    name VARCHAR(150) NOT NULL,
    category VARCHAR(100) NOT NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_equipment_name_category
        UNIQUE (name, category),

    CONSTRAINT ck_equipment_name
        CHECK (btrim(name) <> ''),

    CONSTRAINT ck_equipment_category
        CHECK (btrim(category) <> '')
);


CREATE TABLE exercises (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    owner_user_id UUID,

    name_ru VARCHAR(200) NOT NULL,
    name_en VARCHAR(200),

    description TEXT,
    instructions TEXT,
    safety_notes TEXT,

    exercise_type VARCHAR(30) NOT NULL,
    measurement_type VARCHAR(30) NOT NULL,

    load_basis VARCHAR(30),

    visibility VARCHAR(20) NOT NULL,
    is_archived BOOLEAN NOT NULL DEFAULT FALSE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_exercises_owner
        FOREIGN KEY (owner_user_id)
        REFERENCES users (id)
        ON DELETE RESTRICT,

    CONSTRAINT ck_exercises_name
        CHECK (btrim(name_ru) <> ''),

    CONSTRAINT ck_exercises_type
        CHECK (
            exercise_type IN (
                'STRENGTH',
                'CARDIO',
                'STATIC',
                'OTHER'
            )
        ),

    CONSTRAINT ck_exercises_measurement
        CHECK (
            measurement_type IN (
                'WEIGHT_REPS',
                'BODYWEIGHT_REPS',
                'ASSISTED_REPS',
                'TIME',
                'DISTANCE_TIME',
                'REPS_ONLY',
                'WEIGHT_TIME'
            )
        ),

    CONSTRAINT ck_exercises_load_basis
        CHECK (
            load_basis IS NULL
            OR load_basis IN (
                'ONE_IMPLEMENT',
                'TOTAL',
                'EXTERNAL'
            )
        ),

    CONSTRAINT ck_exercises_visibility_owner
        CHECK (
            (
                visibility = 'SYSTEM'
                AND owner_user_id IS NULL
            )
            OR
            (
                visibility = 'PRIVATE'
                AND owner_user_id IS NOT NULL
            )
        )
);

CREATE INDEX ix_exercises_owner
    ON exercises (owner_user_id);


CREATE TABLE exercise_muscles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    exercise_id UUID NOT NULL,
    muscle_group_id UUID NOT NULL,

    role VARCHAR(20) NOT NULL,

    CONSTRAINT fk_exercise_muscles_exercise
        FOREIGN KEY (exercise_id)
        REFERENCES exercises (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_exercise_muscles_muscle
        FOREIGN KEY (muscle_group_id)
        REFERENCES muscle_groups (id)
        ON DELETE RESTRICT,

    CONSTRAINT uq_exercise_muscles_pair
        UNIQUE (exercise_id, muscle_group_id),

    CONSTRAINT ck_exercise_muscles_role
        CHECK (role IN ('PRIMARY', 'SECONDARY'))
);

CREATE INDEX ix_exercise_muscles_muscle
    ON exercise_muscles (muscle_group_id);


CREATE TABLE exercise_equipment (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    exercise_id UUID NOT NULL,
    equipment_id UUID NOT NULL,

    CONSTRAINT fk_exercise_equipment_exercise
        FOREIGN KEY (exercise_id)
        REFERENCES exercises (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_exercise_equipment_equipment
        FOREIGN KEY (equipment_id)
        REFERENCES equipment (id)
        ON DELETE RESTRICT,

    CONSTRAINT uq_exercise_equipment_pair
        UNIQUE (exercise_id, equipment_id)
);

CREATE INDEX ix_exercise_equipment_equipment
    ON exercise_equipment (equipment_id);