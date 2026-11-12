CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    email VARCHAR(320) NOT NULL,

    email_normalized VARCHAR(320)
        GENERATED ALWAYS AS (lower(btrim(email))) STORED,

    password_hash TEXT NOT NULL,
    display_name VARCHAR(100) NOT NULL,

    status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_users_email_normalized
        UNIQUE (email_normalized),

    CONSTRAINT ck_users_email_not_blank
        CHECK (btrim(email) <> ''),

    CONSTRAINT ck_users_password_hash_not_blank
        CHECK (btrim(password_hash) <> ''),

    CONSTRAINT ck_users_display_name_not_blank
        CHECK (btrim(display_name) <> ''),

    CONSTRAINT ck_users_status
        CHECK (
            status IN (
                'ACTIVE',
                'BLOCKED',
                'DELETION_PENDING'
            )
        ),

    CONSTRAINT ck_users_timestamps
        CHECK (updated_at >= created_at)
);


CREATE TABLE user_training_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL,

    experience_level VARCHAR(30),

    preferred_weight_unit VARCHAR(10) NOT NULL DEFAULT 'KG',
    preferred_distance_unit VARCHAR(10) NOT NULL DEFAULT 'KM',

    timezone VARCHAR(100) NOT NULL DEFAULT 'Europe/Moscow',

    default_rest_seconds INTEGER NOT NULL DEFAULT 90,
    training_days_per_week SMALLINT,

    onboarding_completed BOOLEAN NOT NULL DEFAULT FALSE,

    CONSTRAINT fk_training_profiles_user
        FOREIGN KEY (user_id)
        REFERENCES users (id)
        ON DELETE RESTRICT,

    CONSTRAINT uq_training_profiles_user
        UNIQUE (user_id),

    CONSTRAINT ck_training_profiles_experience
        CHECK (
            experience_level IS NULL
            OR experience_level IN (
                'BEGINNER',
                'INTERMEDIATE',
                'ADVANCED'
            )
        ),

    CONSTRAINT ck_training_profiles_weight_unit
        CHECK (preferred_weight_unit IN ('KG', 'LB')),

    CONSTRAINT ck_training_profiles_distance_unit
        CHECK (preferred_distance_unit IN ('KM', 'MILE')),

    CONSTRAINT ck_training_profiles_timezone
        CHECK (btrim(timezone) <> ''),

    CONSTRAINT ck_training_profiles_rest
        CHECK (default_rest_seconds >= 0),

    CONSTRAINT ck_training_profiles_training_days
        CHECK (training_days_per_week BETWEEN 1 AND 7)
);