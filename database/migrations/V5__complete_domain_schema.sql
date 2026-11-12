-- Full logical model: additive upgrade, V1-V4 are unchanged.

CREATE TABLE training_goals (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    code TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE NOT NULL
);

CREATE TABLE metric_definitions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    code TEXT NOT NULL,
    name TEXT NOT NULL,
    dimension TEXT NOT NULL,
    canonical_unit TEXT NOT NULL,
    direction TEXT NOT NULL,
    formula_version TEXT,
    is_active BOOLEAN DEFAULT TRUE NOT NULL
);

CREATE TABLE user_goals (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL,
    training_goal_id UUID NOT NULL,
    metric_id UUID,
    exercise_id UUID,
    priority BIGINT NOT NULL,
    target_value NUMERIC(20,6),
    target_unit TEXT,
    target_date DATE,
    status TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE user_equipment (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL,
    equipment_id UUID NOT NULL,
    notes TEXT
);

CREATE TABLE user_training_days (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL,
    day_of_week BIGINT NOT NULL,
    available_minutes BIGINT
);

ALTER TABLE exercises ADD COLUMN difficulty_level TEXT;

CREATE TABLE exercise_aliases (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    exercise_id UUID NOT NULL,
    alias TEXT NOT NULL,
    locale TEXT NOT NULL
);

CREATE TABLE exercise_alternatives (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    exercise_id UUID NOT NULL,
    alternative_exercise_id UUID NOT NULL,
    reason TEXT,
    priority BIGINT NOT NULL
);

CREATE TABLE media_files (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    owner_user_id UUID,
    scope TEXT NOT NULL,
    storage_key TEXT NOT NULL,
    mime_type TEXT NOT NULL,
    size_bytes BIGINT NOT NULL,
    checksum TEXT NOT NULL,
    status TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE exercise_media (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    exercise_id UUID NOT NULL,
    media_file_id UUID NOT NULL,
    media_type TEXT NOT NULL,
    sort_order BIGINT NOT NULL
);

ALTER TABLE workout_template_versions ADD COLUMN expected_duration_minutes BIGINT;

CREATE TABLE template_exercise_groups (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    template_version_id UUID NOT NULL,
    group_type TEXT NOT NULL,
    name TEXT,
    rounds BIGINT NOT NULL,
    rest_between_rounds BIGINT NOT NULL,
    position BIGINT NOT NULL
);

ALTER TABLE template_exercises ADD COLUMN exercise_group_id UUID;

ALTER TABLE template_exercises ADD COLUMN group_position BIGINT;

ALTER TABLE template_sets ADD COLUMN set_method TEXT DEFAULT 'STRAIGHT' NOT NULL;

CREATE TABLE template_set_segments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    template_set_id UUID NOT NULL,
    position BIGINT NOT NULL,
    target_weight_kg NUMERIC(20,6),
    target_assistance_kg NUMERIC(20,6),
    target_reps_min BIGINT,
    target_reps_max BIGINT,
    target_duration_seconds NUMERIC(20,6),
    rest_after_seconds BIGINT
);

CREATE TABLE training_programs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    owner_user_id UUID NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    difficulty_level TEXT,
    is_archived BOOLEAN DEFAULT FALSE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE training_program_versions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    program_id UUID NOT NULL,
    version_number BIGINT NOT NULL,
    based_on_version_id UUID,
    duration_weeks BIGINT NOT NULL,
    schedule_mode TEXT NOT NULL,
    status TEXT NOT NULL,
    description TEXT,
    published_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE program_goals (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    program_version_id UUID NOT NULL,
    training_goal_id UUID NOT NULL,
    priority BIGINT NOT NULL
);

CREATE TABLE program_blocks (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    program_version_id UUID NOT NULL,
    name TEXT NOT NULL,
    block_type TEXT NOT NULL,
    position BIGINT NOT NULL,
    description TEXT
);

CREATE TABLE program_weeks (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    program_block_id UUID NOT NULL,
    week_number BIGINT NOT NULL,
    name TEXT,
    description TEXT,
    volume_modifier NUMERIC(20,6),
    intensity_modifier NUMERIC(20,6)
);

CREATE TABLE planned_workouts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    program_week_id UUID NOT NULL,
    template_version_id UUID,
    name TEXT NOT NULL,
    position BIGINT NOT NULL,
    day_of_week BIGINT,
    description TEXT
);

CREATE TABLE planned_exercise_groups (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    planned_workout_id UUID NOT NULL,
    group_type TEXT NOT NULL,
    name TEXT,
    rounds BIGINT NOT NULL,
    rest_between_rounds BIGINT NOT NULL,
    position BIGINT NOT NULL
);

CREATE TABLE planned_workout_exercises (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    planned_workout_id UUID NOT NULL,
    exercise_id UUID NOT NULL,
    exercise_group_id UUID,
    position BIGINT NOT NULL,
    group_position BIGINT,
    notes TEXT,
    default_rest_seconds BIGINT
);

CREATE TABLE planned_workout_sets (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    planned_exercise_id UUID NOT NULL,
    position BIGINT NOT NULL,
    set_category TEXT NOT NULL,
    set_method TEXT DEFAULT 'STRAIGHT' NOT NULL,
    effort_mode TEXT NOT NULL,
    target_weight_kg NUMERIC(20,6),
    target_assistance_kg NUMERIC(20,6),
    target_reps_min BIGINT,
    target_reps_max BIGINT,
    target_duration_seconds NUMERIC(20,6),
    target_distance_meters NUMERIC(20,6),
    target_rpe NUMERIC(20,6),
    target_rir NUMERIC(20,6),
    rest_after_seconds BIGINT,
    notes TEXT
);

CREATE TABLE planned_set_segments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    planned_set_id UUID NOT NULL,
    position BIGINT NOT NULL,
    target_weight_kg NUMERIC(20,6),
    target_assistance_kg NUMERIC(20,6),
    target_reps_min BIGINT,
    target_reps_max BIGINT,
    target_duration_seconds NUMERIC(20,6),
    rest_after_seconds BIGINT
);

CREATE TABLE program_runs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL,
    program_version_id UUID NOT NULL,
    started_at TIMESTAMPTZ NOT NULL,
    finished_at TIMESTAMPTZ,
    status TEXT NOT NULL,
    timezone TEXT NOT NULL
);

CREATE TABLE scheduled_workouts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    program_run_id UUID NOT NULL,
    planned_workout_id UUID NOT NULL,
    scheduled_date DATE,
    sequence_number BIGINT NOT NULL,
    status TEXT NOT NULL,
    notes TEXT,
    revision BIGINT DEFAULT 1 NOT NULL
);

CREATE TABLE schedule_changes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    scheduled_workout_id UUID NOT NULL,
    from_date DATE,
    to_date DATE,
    reason TEXT,
    changed_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    changed_by UUID NOT NULL
);

CREATE TABLE progression_policies (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    program_version_id UUID NOT NULL,
    planned_exercise_id UUID,
    strategy TEXT NOT NULL,
    weight_increment_kg NUMERIC(20,6),
    target_reps_min BIGINT,
    target_reps_max BIGINT,
    minimum_success_sessions BIGINT NOT NULL,
    maximum_increment_kg NUMERIC(20,6)
);

CREATE TABLE workout_adjustments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    scheduled_workout_id UUID NOT NULL,
    planned_set_id UUID NOT NULL,
    recommendation_id UUID,
    revision BIGINT DEFAULT 1 NOT NULL,
    target_weight_kg NUMERIC(20,6),
    target_assistance_kg NUMERIC(20,6),
    target_reps_min BIGINT,
    target_reps_max BIGINT,
    target_duration_seconds NUMERIC(20,6),
    target_distance_meters NUMERIC(20,6),
    status TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
);

ALTER TABLE workout_sessions ADD COLUMN scheduled_workout_id UUID;

CREATE TABLE session_exercise_groups (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    session_id UUID NOT NULL,
    group_type TEXT NOT NULL,
    name TEXT,
    rounds BIGINT NOT NULL,
    rest_between_rounds BIGINT NOT NULL,
    position BIGINT NOT NULL
);

ALTER TABLE session_exercises ADD COLUMN planned_exercise_id UUID;

ALTER TABLE session_exercises ADD COLUMN template_exercise_id UUID;

ALTER TABLE session_exercises ADD COLUMN exercise_group_id UUID;

ALTER TABLE session_exercises ADD COLUMN group_position BIGINT;

ALTER TABLE session_sets ADD COLUMN set_method TEXT DEFAULT 'STRAIGHT' NOT NULL;

ALTER TABLE session_sets ADD COLUMN round_number BIGINT;

CREATE TABLE session_set_segments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    session_set_id UUID NOT NULL,
    position BIGINT NOT NULL,
    target_weight_kg NUMERIC(20,6),
    target_assistance_kg NUMERIC(20,6),
    target_reps_min BIGINT,
    target_reps_max BIGINT,
    target_duration_seconds NUMERIC(20,6),
    rest_after_seconds BIGINT,
    actual_weight_kg NUMERIC(20,6),
    actual_assistance_kg NUMERIC(20,6),
    actual_reps BIGINT,
    actual_duration_seconds NUMERIC(20,6),
    actual_distance_meters NUMERIC(20,6),
    actual_rpe NUMERIC(20,6),
    actual_rir NUMERIC(20,6),
    status TEXT NOT NULL,
    completed_at TIMESTAMPTZ,
    notes TEXT
);

CREATE TABLE session_pauses (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    session_id UUID NOT NULL,
    started_at TIMESTAMPTZ NOT NULL,
    ended_at TIMESTAMPTZ
);

CREATE TABLE rest_intervals (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    session_id UUID NOT NULL,
    session_set_id UUID,
    started_at TIMESTAMPTZ NOT NULL,
    ends_at TIMESTAMPTZ NOT NULL,
    ended_at TIMESTAMPTZ,
    status TEXT NOT NULL
);

CREATE TABLE session_media (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    session_id UUID NOT NULL,
    media_file_id UUID NOT NULL,
    caption TEXT,
    sort_order BIGINT NOT NULL
);

CREATE TABLE session_revisions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    session_id UUID NOT NULL,
    revision_number BIGINT NOT NULL,
    changed_by UUID NOT NULL,
    reason TEXT,
    change_summary JSONB NOT NULL,
    changed_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE body_measurements (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL,
    metric_id UUID NOT NULL,
    value NUMERIC(20,6) NOT NULL,
    unit TEXT NOT NULL,
    measured_at TIMESTAMPTZ NOT NULL,
    timezone TEXT NOT NULL,
    notes TEXT
);

CREATE TABLE recovery_checkins (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL,
    session_id UUID,
    recorded_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    timezone TEXT NOT NULL,
    sleep_hours NUMERIC(20,6),
    sleep_quality BIGINT,
    energy BIGINT,
    fatigue BIGINT,
    stress BIGINT,
    notes TEXT
);

CREATE TABLE muscle_soreness (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    checkin_id UUID NOT NULL,
    muscle_group_id UUID NOT NULL,
    score BIGINT NOT NULL,
    notes TEXT
);

CREATE TABLE movement_discomforts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    checkin_id UUID NOT NULL,
    exercise_id UUID,
    body_area TEXT,
    severity BIGINT,
    notes TEXT NOT NULL
);

CREATE TABLE personal_records (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL,
    exercise_id UUID NOT NULL,
    metric_id UUID NOT NULL,
    session_set_id UUID NOT NULL,
    session_segment_id UUID,
    value NUMERIC(20,6) NOT NULL,
    unit TEXT NOT NULL,
    formula_version TEXT NOT NULL,
    computed_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE analytics_snapshots (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL,
    metric_id UUID NOT NULL,
    exercise_id UUID,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    timezone TEXT NOT NULL,
    formula_version TEXT NOT NULL,
    filter_signature TEXT NOT NULL,
    value NUMERIC(20,6),
    computed_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    source_revision TEXT NOT NULL
);

CREATE TABLE foods (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    owner_user_id UUID,
    scope TEXT NOT NULL,
    name TEXT NOT NULL,
    brand TEXT,
    energy_kcal_100g NUMERIC(20,6),
    protein_g_100g NUMERIC(20,6),
    fat_g_100g NUMERIC(20,6),
    carbs_g_100g NUMERIC(20,6),
    source_name TEXT,
    is_archived BOOLEAN DEFAULT FALSE NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE meal_entries (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL,
    eaten_at TIMESTAMPTZ NOT NULL,
    local_date DATE NOT NULL,
    timezone TEXT NOT NULL,
    meal_type TEXT NOT NULL,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE meal_items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    meal_entry_id UUID NOT NULL,
    food_id UUID,
    name_snapshot TEXT NOT NULL,
    quantity_g NUMERIC(20,6) NOT NULL,
    energy_kcal_100g_snapshot NUMERIC(20,6),
    protein_g_100g_snapshot NUMERIC(20,6),
    fat_g_100g_snapshot NUMERIC(20,6),
    carbs_g_100g_snapshot NUMERIC(20,6),
    source_snapshot TEXT,
    position BIGINT NOT NULL
);

CREATE TABLE water_entries (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL,
    drunk_at TIMESTAMPTZ NOT NULL,
    local_date DATE NOT NULL,
    timezone TEXT NOT NULL,
    volume_ml NUMERIC(20,6) NOT NULL,
    notes TEXT
);

CREATE TABLE nutrition_targets (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL,
    valid_from DATE NOT NULL,
    valid_to DATE,
    energy_kcal NUMERIC(20,6),
    protein_g NUMERIC(20,6),
    fat_g NUMERIC(20,6),
    carbs_g NUMERIC(20,6),
    source TEXT NOT NULL
);

CREATE TABLE hydration_targets (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL,
    valid_from DATE NOT NULL,
    valid_to DATE,
    volume_ml NUMERIC(20,6) NOT NULL
);

CREATE TABLE food_recognitions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL,
    media_file_id UUID NOT NULL,
    consent_id UUID NOT NULL,
    status TEXT NOT NULL,
    provider TEXT NOT NULL,
    model_version TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    completed_at TIMESTAMPTZ,
    error_code TEXT,
    meal_entry_id UUID
);

CREATE TABLE food_recognition_items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    recognition_id UUID NOT NULL,
    food_id UUID,
    proposed_name TEXT NOT NULL,
    proposed_quantity_g NUMERIC(20,6),
    confidence NUMERIC(20,6),
    review_status TEXT NOT NULL,
    confirmed_quantity_g NUMERIC(20,6),
    position BIGINT NOT NULL
);

CREATE TABLE user_consents (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL,
    purpose TEXT NOT NULL,
    policy_version TEXT NOT NULL,
    granted_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    revoked_at TIMESTAMPTZ,
    provider_scope TEXT NOT NULL
);

CREATE TABLE ai_analysis_requests (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL,
    consent_id UUID NOT NULL,
    program_run_id UUID,
    status TEXT NOT NULL,
    provider TEXT NOT NULL,
    model_version TEXT NOT NULL,
    prompt_version TEXT NOT NULL,
    context_revision TEXT NOT NULL,
    context_summary JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    completed_at TIMESTAMPTZ,
    error_code TEXT
);

CREATE TABLE ai_recommendations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    analysis_request_id UUID NOT NULL,
    scheduled_workout_id UUID,
    planned_set_id UUID,
    kind TEXT NOT NULL,
    proposal JSONB NOT NULL,
    explanation TEXT NOT NULL,
    confidence NUMERIC(20,6),
    expected_target_revision TEXT,
    status TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    expires_at TIMESTAMPTZ
);

CREATE TABLE ai_decisions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    recommendation_id UUID NOT NULL,
    user_id UUID NOT NULL,
    decision TEXT NOT NULL,
    reason_code TEXT,
    reason_text TEXT,
    decided_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE recommendation_applications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    recommendation_id UUID NOT NULL,
    decision_id UUID NOT NULL,
    template_version_id UUID,
    program_version_id UUID,
    adjustment_id UUID,
    status TEXT NOT NULL,
    applied_at TIMESTAMPTZ,
    error_code TEXT,
    client_operation_id UUID NOT NULL
);

CREATE TABLE sync_operations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL,
    client_operation_id UUID NOT NULL,
    device_id TEXT NOT NULL,
    request_hash TEXT NOT NULL,
    operation_type TEXT NOT NULL,
    status TEXT NOT NULL,
    result_reference JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    expires_at TIMESTAMPTZ
);

CREATE TABLE export_jobs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL,
    scope JSONB NOT NULL,
    status TEXT NOT NULL,
    storage_key TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    completed_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    error_code TEXT
);

ALTER TABLE users ADD CONSTRAINT ck_v5_users_email CHECK (btrim(email) <> '');

ALTER TABLE users ADD CONSTRAINT ck_v5_users_email_normalized CHECK (btrim(email_normalized) <> '');

ALTER TABLE users ADD CONSTRAINT ck_v5_users_password_hash CHECK (btrim(password_hash) <> '');

ALTER TABLE users ADD CONSTRAINT ck_v5_users_display_name CHECK (btrim(display_name) <> '');

ALTER TABLE users ADD CONSTRAINT ck_v5_users_status_enum CHECK (status IN ('ACTIVE','BLOCKED','DELETION_PENDING')) ;

CREATE UNIQUE INDEX uq_v5_users_email_normalized ON users (email_normalized);

CREATE INDEX ix_v5_user_training_profiles_user_id ON user_training_profiles (user_id);

ALTER TABLE user_training_profiles ADD CONSTRAINT ck_v5_user_training_profiles_experience_level_enum CHECK (experience_level IN ('BEGINNER','INTERMEDIATE','ADVANCED')) ;

ALTER TABLE user_training_profiles ADD CONSTRAINT ck_v5_user_training_profiles_preferred_weight_unit_enum CHECK (preferred_weight_unit IN ('KG','LB')) ;

ALTER TABLE user_training_profiles ADD CONSTRAINT ck_v5_user_training_profiles_preferred_distance_unit_enum CHECK (preferred_distance_unit IN ('KM','MILE')) ;

ALTER TABLE user_training_profiles ADD CONSTRAINT ck_v5_user_training_profiles_timezone CHECK (btrim(timezone) <> '');

ALTER TABLE user_training_profiles ADD CONSTRAINT ck_v5_user_training_profiles_default_rest_seconds CHECK (default_rest_seconds >= 0);

CREATE UNIQUE INDEX uq_v5_user_training_profiles_user_id ON user_training_profiles (user_id);

ALTER TABLE training_goals ADD CONSTRAINT ck_v5_training_goals_code CHECK (btrim(code) <> '');

ALTER TABLE training_goals ADD CONSTRAINT ck_v5_training_goals_name CHECK (btrim(name) <> '');

CREATE UNIQUE INDEX uq_v5_training_goals_code ON training_goals (code);

ALTER TABLE metric_definitions ADD CONSTRAINT ck_v5_metric_definitions_code CHECK (btrim(code) <> '');

ALTER TABLE metric_definitions ADD CONSTRAINT ck_v5_metric_definitions_name CHECK (btrim(name) <> '');

ALTER TABLE metric_definitions ADD CONSTRAINT ck_v5_metric_definitions_dimension_enum CHECK (dimension IN ('MASS','LENGTH','TIME','REPS','SCORE','VOLUME')) ;

ALTER TABLE metric_definitions ADD CONSTRAINT ck_v5_metric_definitions_canonical_unit CHECK (btrim(canonical_unit) <> '');

ALTER TABLE metric_definitions ADD CONSTRAINT ck_v5_metric_definitions_direction_enum CHECK (direction IN ('HIGHER','LOWER','TARGET')) ;

CREATE UNIQUE INDEX uq_v5_metric_definitions_code ON metric_definitions (code);

ALTER TABLE user_goals ADD CONSTRAINT fk_user_goals_user_id FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_user_goals_user_id ON user_goals (user_id);

ALTER TABLE user_goals ADD CONSTRAINT fk_user_goals_training_goal_id FOREIGN KEY (training_goal_id) REFERENCES training_goals(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_user_goals_training_goal_id ON user_goals (training_goal_id);

ALTER TABLE user_goals ADD CONSTRAINT fk_user_goals_metric_id FOREIGN KEY (metric_id) REFERENCES metric_definitions(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_user_goals_metric_id ON user_goals (metric_id);

ALTER TABLE user_goals ADD CONSTRAINT fk_user_goals_exercise_id FOREIGN KEY (exercise_id) REFERENCES exercises(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_user_goals_exercise_id ON user_goals (exercise_id);

ALTER TABLE user_goals ADD CONSTRAINT ck_v5_user_goals_priority CHECK (priority > 0);

ALTER TABLE user_goals ADD CONSTRAINT ck_v5_user_goals_target_value CHECK (target_value >= 0 AND target_value NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE user_goals ADD CONSTRAINT ck_v5_user_goals_status_enum CHECK (status IN ('ACTIVE','ACHIEVED','ARCHIVED')) ;

ALTER TABLE user_equipment ADD CONSTRAINT fk_user_equipment_user_id FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_user_equipment_user_id ON user_equipment (user_id);

ALTER TABLE user_equipment ADD CONSTRAINT fk_user_equipment_equipment_id FOREIGN KEY (equipment_id) REFERENCES equipment(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_user_equipment_equipment_id ON user_equipment (equipment_id);

CREATE UNIQUE INDEX uq_v5_user_equipment_equipment_id ON user_equipment (user_id, equipment_id);

ALTER TABLE user_training_days ADD CONSTRAINT fk_user_training_days_user_id FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_user_training_days_user_id ON user_training_days (user_id);

ALTER TABLE user_training_days ADD CHECK (day_of_week BETWEEN 1 AND 7);

ALTER TABLE user_training_days ADD CONSTRAINT ck_v5_user_training_days_available_minutes CHECK (available_minutes > 0);

CREATE UNIQUE INDEX uq_v5_user_training_days_day_of_week ON user_training_days (user_id, day_of_week);

CREATE INDEX ix_v5_exercises_owner_user_id ON exercises (owner_user_id);

ALTER TABLE exercises ADD CONSTRAINT ck_v5_exercises_name_ru CHECK (btrim(name_ru) <> '');

ALTER TABLE exercises ADD CONSTRAINT ck_v5_exercises_exercise_type_enum CHECK (exercise_type IN ('STRENGTH','CARDIO','STATIC','OTHER')) ;

ALTER TABLE exercises ADD CONSTRAINT ck_v5_exercises_load_basis_enum CHECK (load_basis IN ('ONE_IMPLEMENT','TOTAL','EXTERNAL')) ;

ALTER TABLE exercises ADD CONSTRAINT ck_v5_exercises_visibility_enum CHECK (visibility IN ('SYSTEM','PRIVATE')) ;

ALTER TABLE exercise_aliases ADD CONSTRAINT fk_exercise_aliases_exercise_id FOREIGN KEY (exercise_id) REFERENCES exercises(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_exercise_aliases_exercise_id ON exercise_aliases (exercise_id);

ALTER TABLE exercise_aliases ADD CONSTRAINT ck_v5_exercise_aliases_alias CHECK (btrim(alias) <> '');

ALTER TABLE exercise_aliases ADD CONSTRAINT ck_v5_exercise_aliases_locale CHECK (btrim(locale) <> '');

CREATE INDEX ix_v5_muscle_groups_parent_id ON muscle_groups (parent_id);

ALTER TABLE muscle_groups ADD CONSTRAINT ck_v5_muscle_groups_name CHECK (btrim(name) <> '');

ALTER TABLE muscle_groups ADD CONSTRAINT ck_v5_muscle_groups_sort_order CHECK (sort_order >= 0);

CREATE INDEX ix_v5_exercise_muscles_exercise_id ON exercise_muscles (exercise_id);

CREATE INDEX ix_v5_exercise_muscles_muscle_group_id ON exercise_muscles (muscle_group_id);

ALTER TABLE exercise_muscles ADD CONSTRAINT ck_v5_exercise_muscles_role_enum CHECK (role IN ('PRIMARY','SECONDARY')) ;

CREATE UNIQUE INDEX uq_v5_exercise_muscles_muscle_group_id ON exercise_muscles (exercise_id, muscle_group_id);

ALTER TABLE equipment ADD CONSTRAINT ck_v5_equipment_name CHECK (btrim(name) <> '');

ALTER TABLE equipment ADD CONSTRAINT ck_v5_equipment_category CHECK (btrim(category) <> '');

CREATE UNIQUE INDEX uq_v5_equipment_category ON equipment (name, category);

CREATE INDEX ix_v5_exercise_equipment_exercise_id ON exercise_equipment (exercise_id);

CREATE INDEX ix_v5_exercise_equipment_equipment_id ON exercise_equipment (equipment_id);

CREATE UNIQUE INDEX uq_v5_exercise_equipment_equipment_id ON exercise_equipment (exercise_id, equipment_id);

ALTER TABLE exercise_alternatives ADD CONSTRAINT fk_exercise_alternatives_exercise_id FOREIGN KEY (exercise_id) REFERENCES exercises(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_exercise_alternatives_exercise_id ON exercise_alternatives (exercise_id);

ALTER TABLE exercise_alternatives ADD CONSTRAINT fk_exercise_alternatives_alternative_exercise_id FOREIGN KEY (alternative_exercise_id) REFERENCES exercises(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_exercise_alternatives_alternative_exercise_id ON exercise_alternatives (alternative_exercise_id);

ALTER TABLE exercise_alternatives ADD CONSTRAINT ck_v5_exercise_alternatives_priority CHECK (priority > 0);

CREATE UNIQUE INDEX uq_v5_exercise_alternatives_alternative_exercise_id ON exercise_alternatives (exercise_id, alternative_exercise_id);

ALTER TABLE media_files ADD CONSTRAINT fk_media_files_owner_user_id FOREIGN KEY (owner_user_id) REFERENCES users(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_media_files_owner_user_id ON media_files (owner_user_id);

ALTER TABLE media_files ADD CONSTRAINT ck_v5_media_files_scope_enum CHECK (scope IN ('PRIVATE','SYSTEM')) ;

ALTER TABLE media_files ADD CONSTRAINT ck_v5_media_files_storage_key CHECK (btrim(storage_key) <> '');

ALTER TABLE media_files ADD CONSTRAINT ck_v5_media_files_mime_type CHECK (btrim(mime_type) <> '');

ALTER TABLE media_files ADD CONSTRAINT ck_v5_media_files_checksum CHECK (btrim(checksum) <> '');

ALTER TABLE media_files ADD CONSTRAINT ck_v5_media_files_status_enum CHECK (status IN ('PENDING','READY','REJECTED','DELETED')) ;

CREATE UNIQUE INDEX uq_v5_media_files_storage_key ON media_files (storage_key);

ALTER TABLE exercise_media ADD CONSTRAINT fk_exercise_media_exercise_id FOREIGN KEY (exercise_id) REFERENCES exercises(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_exercise_media_exercise_id ON exercise_media (exercise_id);

ALTER TABLE exercise_media ADD CONSTRAINT fk_exercise_media_media_file_id FOREIGN KEY (media_file_id) REFERENCES media_files(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_exercise_media_media_file_id ON exercise_media (media_file_id);

ALTER TABLE exercise_media ADD CONSTRAINT ck_v5_exercise_media_media_type_enum CHECK (media_type IN ('IMAGE','VIDEO')) ;

ALTER TABLE exercise_media ADD CONSTRAINT ck_v5_exercise_media_sort_order CHECK (sort_order >= 0);

CREATE UNIQUE INDEX uq_v5_exercise_media_media_file_id ON exercise_media (exercise_id, media_file_id);

CREATE INDEX ix_v5_workout_templates_owner_user_id ON workout_templates (owner_user_id);

ALTER TABLE workout_templates ADD CONSTRAINT ck_v5_workout_templates_name CHECK (btrim(name) <> '');

CREATE INDEX ix_v5_workout_template_versions_template_id ON workout_template_versions (template_id);

ALTER TABLE workout_template_versions ADD CONSTRAINT ck_v5_workout_template_versions_version_number CHECK (version_number > 0);

CREATE INDEX ix_v5_workout_template_versions_based_on_version_id ON workout_template_versions (based_on_version_id);

ALTER TABLE workout_template_versions ADD CONSTRAINT ck_v5_workout_template_versions_status_enum CHECK (status IN ('DRAFT','PUBLISHED')) ;

ALTER TABLE workout_template_versions ADD CONSTRAINT ck_v5_workout_template_versions_expected_duration_minutes CHECK (expected_duration_minutes > 0);

CREATE UNIQUE INDEX uq_v5_workout_template_versions_version_number ON workout_template_versions (template_id, version_number);

ALTER TABLE template_exercise_groups ADD CONSTRAINT fk_template_exercise_groups_template_version_id FOREIGN KEY (template_version_id) REFERENCES workout_template_versions(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_template_exercise_groups_template_version_id ON template_exercise_groups (template_version_id);

ALTER TABLE template_exercise_groups ADD CONSTRAINT ck_v5_template_exercise_groups_group_type_enum CHECK (group_type IN ('SUPERSET','CIRCUIT')) ;

ALTER TABLE template_exercise_groups ADD CONSTRAINT ck_v5_template_exercise_groups_rounds CHECK (rounds > 0);

ALTER TABLE template_exercise_groups ADD CONSTRAINT ck_v5_template_exercise_groups_rest_between_rounds CHECK (rest_between_rounds >= 0);

ALTER TABLE template_exercise_groups ADD CONSTRAINT ck_v5_template_exercise_groups_position CHECK (position > 0);

CREATE UNIQUE INDEX uq_v5_template_exercise_groups_position ON template_exercise_groups (template_version_id, position);

CREATE INDEX ix_v5_template_exercises_template_version_id ON template_exercises (template_version_id);

CREATE INDEX ix_v5_template_exercises_exercise_id ON template_exercises (exercise_id);

ALTER TABLE template_exercises ADD CONSTRAINT fk_template_exercises_exercise_group_id FOREIGN KEY (exercise_group_id) REFERENCES template_exercise_groups(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_template_exercises_exercise_group_id ON template_exercises (exercise_group_id);

ALTER TABLE template_exercises ADD CONSTRAINT ck_v5_template_exercises_position CHECK (position > 0);

ALTER TABLE template_exercises ADD CONSTRAINT ck_v5_template_exercises_group_position CHECK (group_position > 0);

ALTER TABLE template_exercises ADD CONSTRAINT ck_v5_template_exercises_default_rest_seconds CHECK (default_rest_seconds >= 0);

CREATE UNIQUE INDEX uq_v5_template_exercises_position ON template_exercises (template_version_id, position);

CREATE INDEX ix_v5_template_sets_template_exercise_id ON template_sets (template_exercise_id);

ALTER TABLE template_sets ADD CONSTRAINT ck_v5_template_sets_position CHECK (position > 0);

ALTER TABLE template_sets ADD CONSTRAINT ck_v5_template_sets_set_category_enum CHECK (set_category IN ('WARMUP','WORKING')) ;

ALTER TABLE template_sets ADD CONSTRAINT ck_v5_template_sets_set_method_enum CHECK (set_method IN ('STRAIGHT','DROP','CLUSTER')) ;

ALTER TABLE template_sets ADD CONSTRAINT ck_v5_template_sets_effort_mode_enum CHECK (effort_mode IN ('NORMAL','FAILURE','AMRAP')) ;

ALTER TABLE template_sets ADD CONSTRAINT ck_v5_template_sets_target_weight_kg CHECK (target_weight_kg >= 0 AND target_weight_kg NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE template_sets ADD CONSTRAINT ck_v5_template_sets_target_assistance_kg CHECK (target_assistance_kg >= 0 AND target_assistance_kg NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE template_sets ADD CONSTRAINT ck_v5_template_sets_target_duration_seconds CHECK (target_duration_seconds >= 0 AND target_duration_seconds NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE template_sets ADD CONSTRAINT ck_v5_template_sets_target_distance_meters CHECK (target_distance_meters >= 0 AND target_distance_meters NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE template_sets ADD CONSTRAINT ck_v5_template_sets_target_rpe CHECK (target_rpe >= 0 AND target_rpe NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE template_sets ADD CHECK (target_rpe BETWEEN 1 AND 10);

ALTER TABLE template_sets ADD CONSTRAINT ck_v5_template_sets_target_rir CHECK (target_rir >= 0 AND target_rir NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE template_sets ADD CHECK (target_rir BETWEEN 0 AND 10);

ALTER TABLE template_sets ADD CONSTRAINT ck_v5_template_sets_rest_after_seconds CHECK (rest_after_seconds >= 0);

CREATE UNIQUE INDEX uq_v5_template_sets_position ON template_sets (template_exercise_id, position);

ALTER TABLE template_set_segments ADD CONSTRAINT fk_template_set_segments_template_set_id FOREIGN KEY (template_set_id) REFERENCES template_sets(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_template_set_segments_template_set_id ON template_set_segments (template_set_id);

ALTER TABLE template_set_segments ADD CONSTRAINT ck_v5_template_set_segments_position CHECK (position > 0);

ALTER TABLE template_set_segments ADD CONSTRAINT ck_v5_template_set_segments_target_weight_kg CHECK (target_weight_kg >= 0 AND target_weight_kg NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE template_set_segments ADD CONSTRAINT ck_v5_template_set_segments_target_assistance_kg CHECK (target_assistance_kg >= 0 AND target_assistance_kg NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE template_set_segments ADD CONSTRAINT ck_v5_template_set_segments_target_duration_seconds CHECK (target_duration_seconds >= 0 AND target_duration_seconds NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE template_set_segments ADD CONSTRAINT ck_v5_template_set_segments_rest_after_seconds CHECK (rest_after_seconds >= 0);

CREATE UNIQUE INDEX uq_v5_template_set_segments_position ON template_set_segments (template_set_id, position);

ALTER TABLE training_programs ADD CONSTRAINT fk_training_programs_owner_user_id FOREIGN KEY (owner_user_id) REFERENCES users(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_training_programs_owner_user_id ON training_programs (owner_user_id);

ALTER TABLE training_programs ADD CONSTRAINT ck_v5_training_programs_name CHECK (btrim(name) <> '');

ALTER TABLE training_program_versions ADD CONSTRAINT fk_training_program_versions_program_id FOREIGN KEY (program_id) REFERENCES training_programs(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_training_program_versions_program_id ON training_program_versions (program_id);

ALTER TABLE training_program_versions ADD CONSTRAINT ck_v5_training_program_versions_version_number CHECK (version_number > 0);

ALTER TABLE training_program_versions ADD CONSTRAINT fk_training_program_versions_based_on_version_id FOREIGN KEY (based_on_version_id) REFERENCES training_program_versions(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_training_program_versions_based_on_version_id ON training_program_versions (based_on_version_id);

ALTER TABLE training_program_versions ADD CONSTRAINT ck_v5_training_program_versions_duration_weeks CHECK (duration_weeks > 0);

ALTER TABLE training_program_versions ADD CONSTRAINT ck_v5_training_program_versions_schedule_mode_enum CHECK (schedule_mode IN ('CALENDAR','SEQUENTIAL')) ;

ALTER TABLE training_program_versions ADD CONSTRAINT ck_v5_training_program_versions_status_enum CHECK (status IN ('DRAFT','PUBLISHED')) ;

CREATE UNIQUE INDEX uq_v5_training_program_versions_version_number ON training_program_versions (program_id, version_number);

ALTER TABLE program_goals ADD CONSTRAINT fk_program_goals_program_version_id FOREIGN KEY (program_version_id) REFERENCES training_program_versions(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_program_goals_program_version_id ON program_goals (program_version_id);

ALTER TABLE program_goals ADD CONSTRAINT fk_program_goals_training_goal_id FOREIGN KEY (training_goal_id) REFERENCES training_goals(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_program_goals_training_goal_id ON program_goals (training_goal_id);

ALTER TABLE program_goals ADD CONSTRAINT ck_v5_program_goals_priority CHECK (priority > 0);

CREATE UNIQUE INDEX uq_v5_program_goals_training_goal_id ON program_goals (program_version_id, training_goal_id);

ALTER TABLE program_blocks ADD CONSTRAINT fk_program_blocks_program_version_id FOREIGN KEY (program_version_id) REFERENCES training_program_versions(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_program_blocks_program_version_id ON program_blocks (program_version_id);

ALTER TABLE program_blocks ADD CONSTRAINT ck_v5_program_blocks_name CHECK (btrim(name) <> '');

ALTER TABLE program_blocks ADD CONSTRAINT ck_v5_program_blocks_block_type_enum CHECK (block_type IN ('DEVELOPMENT','DELOAD','ASSESSMENT','OTHER')) ;

ALTER TABLE program_blocks ADD CONSTRAINT ck_v5_program_blocks_position CHECK (position > 0);

CREATE UNIQUE INDEX uq_v5_program_blocks_position ON program_blocks (program_version_id, position);

ALTER TABLE program_weeks ADD CONSTRAINT fk_program_weeks_program_block_id FOREIGN KEY (program_block_id) REFERENCES program_blocks(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_program_weeks_program_block_id ON program_weeks (program_block_id);

ALTER TABLE program_weeks ADD CONSTRAINT ck_v5_program_weeks_week_number CHECK (week_number > 0);

ALTER TABLE program_weeks ADD CONSTRAINT ck_v5_program_weeks_volume_modifier CHECK (volume_modifier >= 0 AND volume_modifier NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE program_weeks ADD CONSTRAINT ck_v5_program_weeks_intensity_modifier CHECK (intensity_modifier >= 0 AND intensity_modifier NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE planned_workouts ADD CONSTRAINT fk_planned_workouts_program_week_id FOREIGN KEY (program_week_id) REFERENCES program_weeks(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_planned_workouts_program_week_id ON planned_workouts (program_week_id);

ALTER TABLE planned_workouts ADD CONSTRAINT fk_planned_workouts_template_version_id FOREIGN KEY (template_version_id) REFERENCES workout_template_versions(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_planned_workouts_template_version_id ON planned_workouts (template_version_id);

ALTER TABLE planned_workouts ADD CONSTRAINT ck_v5_planned_workouts_name CHECK (btrim(name) <> '');

ALTER TABLE planned_workouts ADD CONSTRAINT ck_v5_planned_workouts_position CHECK (position > 0);

ALTER TABLE planned_workouts ADD CHECK (day_of_week BETWEEN 1 AND 7);

CREATE UNIQUE INDEX uq_v5_planned_workouts_position ON planned_workouts (program_week_id, position);

ALTER TABLE planned_exercise_groups ADD CONSTRAINT fk_planned_exercise_groups_planned_workout_id FOREIGN KEY (planned_workout_id) REFERENCES planned_workouts(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_planned_exercise_groups_planned_workout_id ON planned_exercise_groups (planned_workout_id);

ALTER TABLE planned_exercise_groups ADD CONSTRAINT ck_v5_planned_exercise_groups_group_type_enum CHECK (group_type IN ('SUPERSET','CIRCUIT')) ;

ALTER TABLE planned_exercise_groups ADD CONSTRAINT ck_v5_planned_exercise_groups_rounds CHECK (rounds > 0);

ALTER TABLE planned_exercise_groups ADD CONSTRAINT ck_v5_planned_exercise_groups_rest_between_rounds CHECK (rest_between_rounds >= 0);

ALTER TABLE planned_exercise_groups ADD CONSTRAINT ck_v5_planned_exercise_groups_position CHECK (position > 0);

CREATE UNIQUE INDEX uq_v5_planned_exercise_groups_position ON planned_exercise_groups (planned_workout_id, position);

ALTER TABLE planned_workout_exercises ADD CONSTRAINT fk_planned_workout_exercises_planned_workout_id FOREIGN KEY (planned_workout_id) REFERENCES planned_workouts(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_planned_workout_exercises_planned_workout_id ON planned_workout_exercises (planned_workout_id);

ALTER TABLE planned_workout_exercises ADD CONSTRAINT fk_planned_workout_exercises_exercise_id FOREIGN KEY (exercise_id) REFERENCES exercises(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_planned_workout_exercises_exercise_id ON planned_workout_exercises (exercise_id);

ALTER TABLE planned_workout_exercises ADD CONSTRAINT fk_planned_workout_exercises_exercise_group_id FOREIGN KEY (exercise_group_id) REFERENCES planned_exercise_groups(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_planned_workout_exercises_exercise_group_id ON planned_workout_exercises (exercise_group_id);

ALTER TABLE planned_workout_exercises ADD CONSTRAINT ck_v5_planned_workout_exercises_position CHECK (position > 0);

ALTER TABLE planned_workout_exercises ADD CONSTRAINT ck_v5_planned_workout_exercises_group_position CHECK (group_position > 0);

ALTER TABLE planned_workout_exercises ADD CONSTRAINT ck_v5_planned_workout_exercises_default_rest_seconds CHECK (default_rest_seconds >= 0);

CREATE UNIQUE INDEX uq_v5_planned_workout_exercises_position ON planned_workout_exercises (planned_workout_id, position);

CREATE UNIQUE INDEX uq_v5_planned_workout_exercises_group_position ON planned_workout_exercises (exercise_group_id, group_position);

ALTER TABLE planned_workout_sets ADD CONSTRAINT fk_planned_workout_sets_planned_exercise_id FOREIGN KEY (planned_exercise_id) REFERENCES planned_workout_exercises(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_planned_workout_sets_planned_exercise_id ON planned_workout_sets (planned_exercise_id);

ALTER TABLE planned_workout_sets ADD CONSTRAINT ck_v5_planned_workout_sets_position CHECK (position > 0);

ALTER TABLE planned_workout_sets ADD CONSTRAINT ck_v5_planned_workout_sets_set_category_enum CHECK (set_category IN ('WARMUP','WORKING')) ;

ALTER TABLE planned_workout_sets ADD CONSTRAINT ck_v5_planned_workout_sets_set_method_enum CHECK (set_method IN ('STRAIGHT','DROP','CLUSTER')) ;

ALTER TABLE planned_workout_sets ADD CONSTRAINT ck_v5_planned_workout_sets_effort_mode_enum CHECK (effort_mode IN ('NORMAL','FAILURE','AMRAP')) ;

ALTER TABLE planned_workout_sets ADD CONSTRAINT ck_v5_planned_workout_sets_target_weight_kg CHECK (target_weight_kg >= 0 AND target_weight_kg NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE planned_workout_sets ADD CONSTRAINT ck_v5_planned_workout_sets_target_assistance_kg CHECK (target_assistance_kg >= 0 AND target_assistance_kg NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE planned_workout_sets ADD CONSTRAINT ck_v5_planned_workout_sets_target_duration_seconds CHECK (target_duration_seconds >= 0 AND target_duration_seconds NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE planned_workout_sets ADD CONSTRAINT ck_v5_planned_workout_sets_target_distance_meters CHECK (target_distance_meters >= 0 AND target_distance_meters NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE planned_workout_sets ADD CONSTRAINT ck_v5_planned_workout_sets_target_rpe CHECK (target_rpe >= 0 AND target_rpe NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE planned_workout_sets ADD CHECK (target_rpe BETWEEN 1 AND 10);

ALTER TABLE planned_workout_sets ADD CONSTRAINT ck_v5_planned_workout_sets_target_rir CHECK (target_rir >= 0 AND target_rir NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE planned_workout_sets ADD CHECK (target_rir BETWEEN 0 AND 10);

ALTER TABLE planned_workout_sets ADD CONSTRAINT ck_v5_planned_workout_sets_rest_after_seconds CHECK (rest_after_seconds >= 0);

CREATE UNIQUE INDEX uq_v5_planned_workout_sets_position ON planned_workout_sets (planned_exercise_id, position);

ALTER TABLE planned_set_segments ADD CONSTRAINT fk_planned_set_segments_planned_set_id FOREIGN KEY (planned_set_id) REFERENCES planned_workout_sets(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_planned_set_segments_planned_set_id ON planned_set_segments (planned_set_id);

ALTER TABLE planned_set_segments ADD CONSTRAINT ck_v5_planned_set_segments_position CHECK (position > 0);

ALTER TABLE planned_set_segments ADD CONSTRAINT ck_v5_planned_set_segments_target_weight_kg CHECK (target_weight_kg >= 0 AND target_weight_kg NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE planned_set_segments ADD CONSTRAINT ck_v5_planned_set_segments_target_assistance_kg CHECK (target_assistance_kg >= 0 AND target_assistance_kg NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE planned_set_segments ADD CONSTRAINT ck_v5_planned_set_segments_target_duration_seconds CHECK (target_duration_seconds >= 0 AND target_duration_seconds NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE planned_set_segments ADD CONSTRAINT ck_v5_planned_set_segments_rest_after_seconds CHECK (rest_after_seconds >= 0);

CREATE UNIQUE INDEX uq_v5_planned_set_segments_position ON planned_set_segments (planned_set_id, position);

ALTER TABLE program_runs ADD CONSTRAINT fk_program_runs_user_id FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_program_runs_user_id ON program_runs (user_id);

ALTER TABLE program_runs ADD CONSTRAINT fk_program_runs_program_version_id FOREIGN KEY (program_version_id) REFERENCES training_program_versions(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_program_runs_program_version_id ON program_runs (program_version_id);

ALTER TABLE program_runs ADD CONSTRAINT ck_v5_program_runs_status_enum CHECK (status IN ('ACTIVE','PAUSED','COMPLETED','CANCELLED')) ;

ALTER TABLE program_runs ADD CONSTRAINT ck_v5_program_runs_timezone CHECK (btrim(timezone) <> '');

ALTER TABLE scheduled_workouts ADD CONSTRAINT fk_scheduled_workouts_program_run_id FOREIGN KEY (program_run_id) REFERENCES program_runs(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_scheduled_workouts_program_run_id ON scheduled_workouts (program_run_id);

ALTER TABLE scheduled_workouts ADD CONSTRAINT fk_scheduled_workouts_planned_workout_id FOREIGN KEY (planned_workout_id) REFERENCES planned_workouts(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_scheduled_workouts_planned_workout_id ON scheduled_workouts (planned_workout_id);

ALTER TABLE scheduled_workouts ADD CONSTRAINT ck_v5_scheduled_workouts_sequence_number CHECK (sequence_number > 0);

ALTER TABLE scheduled_workouts ADD CONSTRAINT ck_v5_scheduled_workouts_status_enum CHECK (status IN ('PLANNED','IN_PROGRESS','COMPLETED','SKIPPED','CANCELLED')) ;

ALTER TABLE scheduled_workouts ADD CONSTRAINT ck_v5_scheduled_workouts_revision CHECK (revision > 0);

CREATE UNIQUE INDEX uq_v5_scheduled_workouts_planned_workout_id ON scheduled_workouts (program_run_id, planned_workout_id);

CREATE UNIQUE INDEX uq_v5_scheduled_workouts_sequence_number ON scheduled_workouts (program_run_id, sequence_number);

ALTER TABLE schedule_changes ADD CONSTRAINT fk_schedule_changes_scheduled_workout_id FOREIGN KEY (scheduled_workout_id) REFERENCES scheduled_workouts(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_schedule_changes_scheduled_workout_id ON schedule_changes (scheduled_workout_id);

ALTER TABLE schedule_changes ADD CONSTRAINT fk_schedule_changes_changed_by FOREIGN KEY (changed_by) REFERENCES users(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_schedule_changes_changed_by ON schedule_changes (changed_by);

ALTER TABLE progression_policies ADD CONSTRAINT fk_progression_policies_program_version_id FOREIGN KEY (program_version_id) REFERENCES training_program_versions(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_progression_policies_program_version_id ON progression_policies (program_version_id);

ALTER TABLE progression_policies ADD CONSTRAINT fk_progression_policies_planned_exercise_id FOREIGN KEY (planned_exercise_id) REFERENCES planned_workout_exercises(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_progression_policies_planned_exercise_id ON progression_policies (planned_exercise_id);

ALTER TABLE progression_policies ADD CONSTRAINT ck_v5_progression_policies_strategy_enum CHECK (strategy IN ('MANUAL','DOUBLE_PROGRESSION','CUSTOM')) ;

ALTER TABLE progression_policies ADD CONSTRAINT ck_v5_progression_policies_weight_increment_kg CHECK (weight_increment_kg >= 0 AND weight_increment_kg NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE progression_policies ADD CONSTRAINT ck_v5_progression_policies_minimum_success_sessions CHECK (minimum_success_sessions > 0);

ALTER TABLE progression_policies ADD CONSTRAINT ck_v5_progression_policies_maximum_increment_kg CHECK (maximum_increment_kg >= 0 AND maximum_increment_kg NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE workout_adjustments ADD CONSTRAINT fk_workout_adjustments_scheduled_workout_id FOREIGN KEY (scheduled_workout_id) REFERENCES scheduled_workouts(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_workout_adjustments_scheduled_workout_id ON workout_adjustments (scheduled_workout_id);

ALTER TABLE workout_adjustments ADD CONSTRAINT fk_workout_adjustments_planned_set_id FOREIGN KEY (planned_set_id) REFERENCES planned_workout_sets(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_workout_adjustments_planned_set_id ON workout_adjustments (planned_set_id);

ALTER TABLE workout_adjustments ADD CONSTRAINT fk_workout_adjustments_recommendation_id FOREIGN KEY (recommendation_id) REFERENCES ai_recommendations(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_workout_adjustments_recommendation_id ON workout_adjustments (recommendation_id);

ALTER TABLE workout_adjustments ADD CONSTRAINT ck_v5_workout_adjustments_revision CHECK (revision > 0);

ALTER TABLE workout_adjustments ADD CONSTRAINT ck_v5_workout_adjustments_target_weight_kg CHECK (target_weight_kg >= 0 AND target_weight_kg NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE workout_adjustments ADD CONSTRAINT ck_v5_workout_adjustments_target_assistance_kg CHECK (target_assistance_kg >= 0 AND target_assistance_kg NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE workout_adjustments ADD CONSTRAINT ck_v5_workout_adjustments_target_duration_seconds CHECK (target_duration_seconds >= 0 AND target_duration_seconds NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE workout_adjustments ADD CONSTRAINT ck_v5_workout_adjustments_target_distance_meters CHECK (target_distance_meters >= 0 AND target_distance_meters NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE workout_adjustments ADD CONSTRAINT ck_v5_workout_adjustments_status_enum CHECK (status IN ('ACTIVE','SUPERSEDED','CANCELLED')) ;

CREATE UNIQUE INDEX uq_v5_workout_adjustments_revision ON workout_adjustments (scheduled_workout_id, planned_set_id, revision);

CREATE INDEX ix_v5_workout_sessions_user_id ON workout_sessions (user_id);

CREATE INDEX ix_v5_workout_sessions_template_version_id ON workout_sessions (template_version_id);

ALTER TABLE workout_sessions ADD CONSTRAINT fk_workout_sessions_scheduled_workout_id FOREIGN KEY (scheduled_workout_id) REFERENCES scheduled_workouts(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_workout_sessions_scheduled_workout_id ON workout_sessions (scheduled_workout_id);

ALTER TABLE workout_sessions ADD CONSTRAINT ck_v5_workout_sessions_name_snapshot CHECK (btrim(name_snapshot) <> '');

ALTER TABLE workout_sessions ADD CONSTRAINT ck_v5_workout_sessions_status_enum CHECK (status IN ('IN_PROGRESS','PAUSED','COMPLETED','DISCARDED')) ;

ALTER TABLE workout_sessions ADD CONSTRAINT ck_v5_workout_sessions_timezone CHECK (btrim(timezone) <> '');

ALTER TABLE workout_sessions ADD CONSTRAINT ck_v5_workout_sessions_revision CHECK (revision > 0);

CREATE UNIQUE INDEX uq_v5_workout_sessions_client_operation_id ON workout_sessions (user_id, client_operation_id);

ALTER TABLE session_exercise_groups ADD CONSTRAINT fk_session_exercise_groups_session_id FOREIGN KEY (session_id) REFERENCES workout_sessions(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_session_exercise_groups_session_id ON session_exercise_groups (session_id);

ALTER TABLE session_exercise_groups ADD CONSTRAINT ck_v5_session_exercise_groups_group_type_enum CHECK (group_type IN ('SUPERSET','CIRCUIT')) ;

ALTER TABLE session_exercise_groups ADD CONSTRAINT ck_v5_session_exercise_groups_rounds CHECK (rounds > 0);

ALTER TABLE session_exercise_groups ADD CONSTRAINT ck_v5_session_exercise_groups_rest_between_rounds CHECK (rest_between_rounds >= 0);

ALTER TABLE session_exercise_groups ADD CONSTRAINT ck_v5_session_exercise_groups_position CHECK (position > 0);

CREATE UNIQUE INDEX uq_v5_session_exercise_groups_position ON session_exercise_groups (session_id, position);

CREATE INDEX ix_v5_session_exercises_session_id ON session_exercises (session_id);

CREATE INDEX ix_v5_session_exercises_exercise_id ON session_exercises (exercise_id);

ALTER TABLE session_exercises ADD CONSTRAINT fk_session_exercises_planned_exercise_id FOREIGN KEY (planned_exercise_id) REFERENCES planned_workout_exercises(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_session_exercises_planned_exercise_id ON session_exercises (planned_exercise_id);

ALTER TABLE session_exercises ADD CONSTRAINT fk_session_exercises_template_exercise_id FOREIGN KEY (template_exercise_id) REFERENCES template_exercises(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_session_exercises_template_exercise_id ON session_exercises (template_exercise_id);

ALTER TABLE session_exercises ADD CONSTRAINT fk_session_exercises_exercise_group_id FOREIGN KEY (exercise_group_id) REFERENCES session_exercise_groups(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_session_exercises_exercise_group_id ON session_exercises (exercise_group_id);

CREATE INDEX ix_v5_session_exercises_original_exercise_id ON session_exercises (original_exercise_id);

ALTER TABLE session_exercises ADD CONSTRAINT ck_v5_session_exercises_name_snapshot CHECK (btrim(name_snapshot) <> '');

ALTER TABLE session_exercises ADD CONSTRAINT ck_v5_session_exercises_position CHECK (position > 0);

ALTER TABLE session_exercises ADD CONSTRAINT ck_v5_session_exercises_group_position CHECK (group_position > 0);

CREATE UNIQUE INDEX uq_v5_session_exercises_position ON session_exercises (session_id, position);

CREATE UNIQUE INDEX uq_v5_session_exercises_group_position ON session_exercises (exercise_group_id, group_position);

CREATE INDEX ix_v5_session_sets_session_exercise_id ON session_sets (session_exercise_id);

ALTER TABLE session_sets ADD CONSTRAINT ck_v5_session_sets_position CHECK (position > 0);

ALTER TABLE session_sets ADD CONSTRAINT ck_v5_session_sets_set_category_enum CHECK (set_category IN ('WARMUP','WORKING')) ;

ALTER TABLE session_sets ADD CONSTRAINT ck_v5_session_sets_set_method_enum CHECK (set_method IN ('STRAIGHT','DROP','CLUSTER')) ;

ALTER TABLE session_sets ADD CONSTRAINT ck_v5_session_sets_effort_mode_enum CHECK (effort_mode IN ('NORMAL','FAILURE','AMRAP')) ;

ALTER TABLE session_sets ADD CONSTRAINT ck_v5_session_sets_target_weight_kg CHECK (target_weight_kg >= 0 AND target_weight_kg NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE session_sets ADD CONSTRAINT ck_v5_session_sets_target_assistance_kg CHECK (target_assistance_kg >= 0 AND target_assistance_kg NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE session_sets ADD CONSTRAINT ck_v5_session_sets_target_duration_seconds CHECK (target_duration_seconds >= 0 AND target_duration_seconds NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE session_sets ADD CONSTRAINT ck_v5_session_sets_target_distance_meters CHECK (target_distance_meters >= 0 AND target_distance_meters NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE session_sets ADD CONSTRAINT ck_v5_session_sets_target_rpe CHECK (target_rpe >= 0 AND target_rpe NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE session_sets ADD CHECK (target_rpe BETWEEN 1 AND 10);

ALTER TABLE session_sets ADD CONSTRAINT ck_v5_session_sets_target_rir CHECK (target_rir >= 0 AND target_rir NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE session_sets ADD CHECK (target_rir BETWEEN 0 AND 10);

ALTER TABLE session_sets ADD CONSTRAINT ck_v5_session_sets_rest_after_seconds CHECK (rest_after_seconds >= 0);

ALTER TABLE session_sets ADD CONSTRAINT ck_v5_session_sets_actual_weight_kg CHECK (actual_weight_kg >= 0 AND actual_weight_kg NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE session_sets ADD CONSTRAINT ck_v5_session_sets_actual_assistance_kg CHECK (actual_assistance_kg >= 0 AND actual_assistance_kg NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE session_sets ADD CONSTRAINT ck_v5_session_sets_actual_duration_seconds CHECK (actual_duration_seconds >= 0 AND actual_duration_seconds NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE session_sets ADD CONSTRAINT ck_v5_session_sets_actual_distance_meters CHECK (actual_distance_meters >= 0 AND actual_distance_meters NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE session_sets ADD CONSTRAINT ck_v5_session_sets_actual_rpe CHECK (actual_rpe >= 0 AND actual_rpe NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE session_sets ADD CHECK (actual_rpe BETWEEN 1 AND 10);

ALTER TABLE session_sets ADD CONSTRAINT ck_v5_session_sets_actual_rir CHECK (actual_rir >= 0 AND actual_rir NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE session_sets ADD CHECK (actual_rir BETWEEN 0 AND 10);

ALTER TABLE session_sets ADD CONSTRAINT ck_v5_session_sets_status_enum CHECK (status IN ('PENDING','COMPLETED','SKIPPED')) ;

ALTER TABLE session_sets ADD CONSTRAINT ck_v5_session_sets_round_number CHECK (round_number > 0);

CREATE UNIQUE INDEX uq_v5_session_sets_position ON session_sets (session_exercise_id, position);

ALTER TABLE session_set_segments ADD CONSTRAINT fk_session_set_segments_session_set_id FOREIGN KEY (session_set_id) REFERENCES session_sets(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_session_set_segments_session_set_id ON session_set_segments (session_set_id);

ALTER TABLE session_set_segments ADD CONSTRAINT ck_v5_session_set_segments_position CHECK (position > 0);

ALTER TABLE session_set_segments ADD CONSTRAINT ck_v5_session_set_segments_target_weight_kg CHECK (target_weight_kg >= 0 AND target_weight_kg NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE session_set_segments ADD CONSTRAINT ck_v5_session_set_segments_target_assistance_kg CHECK (target_assistance_kg >= 0 AND target_assistance_kg NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE session_set_segments ADD CONSTRAINT ck_v5_session_set_segments_target_duration_seconds CHECK (target_duration_seconds >= 0 AND target_duration_seconds NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE session_set_segments ADD CONSTRAINT ck_v5_session_set_segments_rest_after_seconds CHECK (rest_after_seconds >= 0);

ALTER TABLE session_set_segments ADD CONSTRAINT ck_v5_session_set_segments_actual_weight_kg CHECK (actual_weight_kg >= 0 AND actual_weight_kg NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE session_set_segments ADD CONSTRAINT ck_v5_session_set_segments_actual_assistance_kg CHECK (actual_assistance_kg >= 0 AND actual_assistance_kg NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE session_set_segments ADD CONSTRAINT ck_v5_session_set_segments_actual_duration_seconds CHECK (actual_duration_seconds >= 0 AND actual_duration_seconds NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE session_set_segments ADD CONSTRAINT ck_v5_session_set_segments_actual_distance_meters CHECK (actual_distance_meters >= 0 AND actual_distance_meters NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE session_set_segments ADD CONSTRAINT ck_v5_session_set_segments_actual_rpe CHECK (actual_rpe >= 0 AND actual_rpe NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE session_set_segments ADD CHECK (actual_rpe BETWEEN 1 AND 10);

ALTER TABLE session_set_segments ADD CONSTRAINT ck_v5_session_set_segments_actual_rir CHECK (actual_rir >= 0 AND actual_rir NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE session_set_segments ADD CHECK (actual_rir BETWEEN 0 AND 10);

ALTER TABLE session_set_segments ADD CONSTRAINT ck_v5_session_set_segments_status_enum CHECK (status IN ('PENDING','COMPLETED','SKIPPED')) ;

CREATE UNIQUE INDEX uq_v5_session_set_segments_position ON session_set_segments (session_set_id, position);

ALTER TABLE session_pauses ADD CONSTRAINT fk_session_pauses_session_id FOREIGN KEY (session_id) REFERENCES workout_sessions(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_session_pauses_session_id ON session_pauses (session_id);

ALTER TABLE rest_intervals ADD CONSTRAINT fk_rest_intervals_session_id FOREIGN KEY (session_id) REFERENCES workout_sessions(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_rest_intervals_session_id ON rest_intervals (session_id);

ALTER TABLE rest_intervals ADD CONSTRAINT fk_rest_intervals_session_set_id FOREIGN KEY (session_set_id) REFERENCES session_sets(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_rest_intervals_session_set_id ON rest_intervals (session_set_id);

ALTER TABLE rest_intervals ADD CONSTRAINT ck_v5_rest_intervals_status_enum CHECK (status IN ('RUNNING','FINISHED','CANCELLED')) ;

ALTER TABLE session_media ADD CONSTRAINT fk_session_media_session_id FOREIGN KEY (session_id) REFERENCES workout_sessions(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_session_media_session_id ON session_media (session_id);

ALTER TABLE session_media ADD CONSTRAINT fk_session_media_media_file_id FOREIGN KEY (media_file_id) REFERENCES media_files(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_session_media_media_file_id ON session_media (media_file_id);

ALTER TABLE session_media ADD CONSTRAINT ck_v5_session_media_sort_order CHECK (sort_order >= 0);

CREATE UNIQUE INDEX uq_v5_session_media_media_file_id ON session_media (session_id, media_file_id);

ALTER TABLE session_revisions ADD CONSTRAINT fk_session_revisions_session_id FOREIGN KEY (session_id) REFERENCES workout_sessions(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_session_revisions_session_id ON session_revisions (session_id);

ALTER TABLE session_revisions ADD CONSTRAINT ck_v5_session_revisions_revision_number CHECK (revision_number > 0);

ALTER TABLE session_revisions ADD CONSTRAINT fk_session_revisions_changed_by FOREIGN KEY (changed_by) REFERENCES users(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_session_revisions_changed_by ON session_revisions (changed_by);

ALTER TABLE session_revisions ADD CONSTRAINT ck_session_revisions_change_summary_object CHECK (jsonb_typeof(change_summary) = 'object');

CREATE UNIQUE INDEX uq_v5_session_revisions_revision_number ON session_revisions (session_id, revision_number);

ALTER TABLE body_measurements ADD CONSTRAINT fk_body_measurements_user_id FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_body_measurements_user_id ON body_measurements (user_id);

ALTER TABLE body_measurements ADD CONSTRAINT fk_body_measurements_metric_id FOREIGN KEY (metric_id) REFERENCES metric_definitions(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_body_measurements_metric_id ON body_measurements (metric_id);

ALTER TABLE body_measurements ADD CONSTRAINT ck_v5_body_measurements_value CHECK (value >= 0 AND value NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE body_measurements ADD CONSTRAINT ck_v5_body_measurements_unit CHECK (btrim(unit) <> '');

ALTER TABLE body_measurements ADD CONSTRAINT ck_v5_body_measurements_timezone CHECK (btrim(timezone) <> '');

ALTER TABLE recovery_checkins ADD CONSTRAINT fk_recovery_checkins_user_id FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_recovery_checkins_user_id ON recovery_checkins (user_id);

ALTER TABLE recovery_checkins ADD CONSTRAINT fk_recovery_checkins_session_id FOREIGN KEY (session_id) REFERENCES workout_sessions(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_recovery_checkins_session_id ON recovery_checkins (session_id);

ALTER TABLE recovery_checkins ADD CONSTRAINT ck_v5_recovery_checkins_timezone CHECK (btrim(timezone) <> '');

ALTER TABLE recovery_checkins ADD CONSTRAINT ck_v5_recovery_checkins_sleep_hours CHECK (sleep_hours >= 0 AND sleep_hours NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE recovery_checkins ADD CHECK (sleep_quality BETWEEN 1 AND 5);

ALTER TABLE recovery_checkins ADD CHECK (energy BETWEEN 1 AND 5);

ALTER TABLE recovery_checkins ADD CHECK (fatigue BETWEEN 1 AND 5);

ALTER TABLE recovery_checkins ADD CHECK (stress BETWEEN 1 AND 5);

ALTER TABLE muscle_soreness ADD CONSTRAINT fk_muscle_soreness_checkin_id FOREIGN KEY (checkin_id) REFERENCES recovery_checkins(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_muscle_soreness_checkin_id ON muscle_soreness (checkin_id);

ALTER TABLE muscle_soreness ADD CONSTRAINT fk_muscle_soreness_muscle_group_id FOREIGN KEY (muscle_group_id) REFERENCES muscle_groups(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_muscle_soreness_muscle_group_id ON muscle_soreness (muscle_group_id);

ALTER TABLE muscle_soreness ADD CHECK (score BETWEEN 1 AND 5);

CREATE UNIQUE INDEX uq_v5_muscle_soreness_muscle_group_id ON muscle_soreness (checkin_id, muscle_group_id);

ALTER TABLE movement_discomforts ADD CONSTRAINT fk_movement_discomforts_checkin_id FOREIGN KEY (checkin_id) REFERENCES recovery_checkins(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_movement_discomforts_checkin_id ON movement_discomforts (checkin_id);

ALTER TABLE movement_discomforts ADD CONSTRAINT fk_movement_discomforts_exercise_id FOREIGN KEY (exercise_id) REFERENCES exercises(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_movement_discomforts_exercise_id ON movement_discomforts (exercise_id);

ALTER TABLE movement_discomforts ADD CHECK (severity BETWEEN 1 AND 5);

ALTER TABLE movement_discomforts ADD CONSTRAINT ck_v5_movement_discomforts_notes CHECK (btrim(notes) <> '');

ALTER TABLE personal_records ADD CONSTRAINT fk_personal_records_user_id FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_personal_records_user_id ON personal_records (user_id);

ALTER TABLE personal_records ADD CONSTRAINT fk_personal_records_exercise_id FOREIGN KEY (exercise_id) REFERENCES exercises(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_personal_records_exercise_id ON personal_records (exercise_id);

ALTER TABLE personal_records ADD CONSTRAINT fk_personal_records_metric_id FOREIGN KEY (metric_id) REFERENCES metric_definitions(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_personal_records_metric_id ON personal_records (metric_id);

ALTER TABLE personal_records ADD CONSTRAINT fk_personal_records_session_set_id FOREIGN KEY (session_set_id) REFERENCES session_sets(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_personal_records_session_set_id ON personal_records (session_set_id);

ALTER TABLE personal_records ADD CONSTRAINT fk_personal_records_session_segment_id FOREIGN KEY (session_segment_id) REFERENCES session_set_segments(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_personal_records_session_segment_id ON personal_records (session_segment_id);

ALTER TABLE personal_records ADD CONSTRAINT ck_v5_personal_records_value CHECK (value >= 0 AND value NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE personal_records ADD CONSTRAINT ck_v5_personal_records_unit CHECK (btrim(unit) <> '');

ALTER TABLE personal_records ADD CONSTRAINT ck_v5_personal_records_formula_version CHECK (btrim(formula_version) <> '');

CREATE UNIQUE INDEX uq_v5_personal_records_formula_version ON personal_records (user_id, exercise_id, metric_id, formula_version);

ALTER TABLE analytics_snapshots ADD CONSTRAINT fk_analytics_snapshots_user_id FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_analytics_snapshots_user_id ON analytics_snapshots (user_id);

ALTER TABLE analytics_snapshots ADD CONSTRAINT fk_analytics_snapshots_metric_id FOREIGN KEY (metric_id) REFERENCES metric_definitions(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_analytics_snapshots_metric_id ON analytics_snapshots (metric_id);

ALTER TABLE analytics_snapshots ADD CONSTRAINT fk_analytics_snapshots_exercise_id FOREIGN KEY (exercise_id) REFERENCES exercises(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_analytics_snapshots_exercise_id ON analytics_snapshots (exercise_id);

ALTER TABLE analytics_snapshots ADD CONSTRAINT ck_v5_analytics_snapshots_timezone CHECK (btrim(timezone) <> '');

ALTER TABLE analytics_snapshots ADD CONSTRAINT ck_v5_analytics_snapshots_formula_version CHECK (btrim(formula_version) <> '');

ALTER TABLE analytics_snapshots ADD CONSTRAINT ck_v5_analytics_snapshots_filter_signature CHECK (btrim(filter_signature) <> '');

ALTER TABLE analytics_snapshots ADD CONSTRAINT ck_v5_analytics_snapshots_value CHECK (value >= 0 AND value NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE analytics_snapshots ADD CONSTRAINT ck_v5_analytics_snapshots_source_revision CHECK (btrim(source_revision) <> '');

ALTER TABLE foods ADD CONSTRAINT fk_foods_owner_user_id FOREIGN KEY (owner_user_id) REFERENCES users(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_foods_owner_user_id ON foods (owner_user_id);

ALTER TABLE foods ADD CONSTRAINT ck_v5_foods_scope_enum CHECK (scope IN ('SYSTEM','PRIVATE')) ;

ALTER TABLE foods ADD CONSTRAINT ck_v5_foods_name CHECK (btrim(name) <> '');

ALTER TABLE foods ADD CONSTRAINT ck_v5_foods_energy_kcal_100g CHECK (energy_kcal_100g >= 0 AND energy_kcal_100g NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE foods ADD CONSTRAINT ck_v5_foods_protein_g_100g CHECK (protein_g_100g >= 0 AND protein_g_100g NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE foods ADD CONSTRAINT ck_v5_foods_fat_g_100g CHECK (fat_g_100g >= 0 AND fat_g_100g NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE foods ADD CONSTRAINT ck_v5_foods_carbs_g_100g CHECK (carbs_g_100g >= 0 AND carbs_g_100g NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE meal_entries ADD CONSTRAINT fk_meal_entries_user_id FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_meal_entries_user_id ON meal_entries (user_id);

ALTER TABLE meal_entries ADD CONSTRAINT ck_v5_meal_entries_timezone CHECK (btrim(timezone) <> '');

ALTER TABLE meal_entries ADD CONSTRAINT ck_v5_meal_entries_meal_type_enum CHECK (meal_type IN ('BREAKFAST','LUNCH','DINNER','SNACK','OTHER')) ;

ALTER TABLE meal_items ADD CONSTRAINT fk_meal_items_meal_entry_id FOREIGN KEY (meal_entry_id) REFERENCES meal_entries(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_meal_items_meal_entry_id ON meal_items (meal_entry_id);

ALTER TABLE meal_items ADD CONSTRAINT fk_meal_items_food_id FOREIGN KEY (food_id) REFERENCES foods(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_meal_items_food_id ON meal_items (food_id);

ALTER TABLE meal_items ADD CONSTRAINT ck_v5_meal_items_name_snapshot CHECK (btrim(name_snapshot) <> '');

ALTER TABLE meal_items ADD CONSTRAINT ck_v5_meal_items_quantity_g CHECK (quantity_g >= 0 AND quantity_g NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE meal_items ADD CONSTRAINT ck_v5_meal_items_energy_kcal_100g_snapshot CHECK (energy_kcal_100g_snapshot >= 0 AND energy_kcal_100g_snapshot NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE meal_items ADD CONSTRAINT ck_v5_meal_items_protein_g_100g_snapshot CHECK (protein_g_100g_snapshot >= 0 AND protein_g_100g_snapshot NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE meal_items ADD CONSTRAINT ck_v5_meal_items_fat_g_100g_snapshot CHECK (fat_g_100g_snapshot >= 0 AND fat_g_100g_snapshot NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE meal_items ADD CONSTRAINT ck_v5_meal_items_carbs_g_100g_snapshot CHECK (carbs_g_100g_snapshot >= 0 AND carbs_g_100g_snapshot NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE meal_items ADD CONSTRAINT ck_v5_meal_items_position CHECK (position > 0);

CREATE UNIQUE INDEX uq_v5_meal_items_position ON meal_items (meal_entry_id, position);

ALTER TABLE water_entries ADD CONSTRAINT fk_water_entries_user_id FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_water_entries_user_id ON water_entries (user_id);

ALTER TABLE water_entries ADD CONSTRAINT ck_v5_water_entries_timezone CHECK (btrim(timezone) <> '');

ALTER TABLE water_entries ADD CONSTRAINT ck_v5_water_entries_volume_ml CHECK (volume_ml >= 0 AND volume_ml NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE nutrition_targets ADD CONSTRAINT fk_nutrition_targets_user_id FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_nutrition_targets_user_id ON nutrition_targets (user_id);

ALTER TABLE nutrition_targets ADD CONSTRAINT ck_v5_nutrition_targets_energy_kcal CHECK (energy_kcal >= 0 AND energy_kcal NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE nutrition_targets ADD CONSTRAINT ck_v5_nutrition_targets_protein_g CHECK (protein_g >= 0 AND protein_g NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE nutrition_targets ADD CONSTRAINT ck_v5_nutrition_targets_fat_g CHECK (fat_g >= 0 AND fat_g NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE nutrition_targets ADD CONSTRAINT ck_v5_nutrition_targets_carbs_g CHECK (carbs_g >= 0 AND carbs_g NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE nutrition_targets ADD CONSTRAINT ck_v5_nutrition_targets_source_enum CHECK (source IN ('MANUAL','ACCEPTED_RECOMMENDATION')) ;

ALTER TABLE hydration_targets ADD CONSTRAINT fk_hydration_targets_user_id FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_hydration_targets_user_id ON hydration_targets (user_id);

ALTER TABLE hydration_targets ADD CONSTRAINT ck_v5_hydration_targets_volume_ml CHECK (volume_ml >= 0 AND volume_ml NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE food_recognitions ADD CONSTRAINT fk_food_recognitions_user_id FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_food_recognitions_user_id ON food_recognitions (user_id);

ALTER TABLE food_recognitions ADD CONSTRAINT fk_food_recognitions_media_file_id FOREIGN KEY (media_file_id) REFERENCES media_files(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_food_recognitions_media_file_id ON food_recognitions (media_file_id);

ALTER TABLE food_recognitions ADD CONSTRAINT fk_food_recognitions_consent_id FOREIGN KEY (consent_id) REFERENCES user_consents(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_food_recognitions_consent_id ON food_recognitions (consent_id);

ALTER TABLE food_recognitions ADD CONSTRAINT ck_v5_food_recognitions_status_enum CHECK (status IN ('PENDING','RUNNING','SUCCEEDED','FAILED','CANCELLED')) ;

ALTER TABLE food_recognitions ADD CONSTRAINT ck_v5_food_recognitions_provider CHECK (btrim(provider) <> '');

ALTER TABLE food_recognitions ADD CONSTRAINT ck_v5_food_recognitions_model_version CHECK (btrim(model_version) <> '');

ALTER TABLE food_recognitions ADD CONSTRAINT fk_food_recognitions_meal_entry_id FOREIGN KEY (meal_entry_id) REFERENCES meal_entries(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_food_recognitions_meal_entry_id ON food_recognitions (meal_entry_id);

ALTER TABLE food_recognition_items ADD CONSTRAINT fk_food_recognition_items_recognition_id FOREIGN KEY (recognition_id) REFERENCES food_recognitions(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_food_recognition_items_recognition_id ON food_recognition_items (recognition_id);

ALTER TABLE food_recognition_items ADD CONSTRAINT fk_food_recognition_items_food_id FOREIGN KEY (food_id) REFERENCES foods(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_food_recognition_items_food_id ON food_recognition_items (food_id);

ALTER TABLE food_recognition_items ADD CONSTRAINT ck_v5_food_recognition_items_proposed_name CHECK (btrim(proposed_name) <> '');

ALTER TABLE food_recognition_items ADD CONSTRAINT ck_v5_food_recognition_items_proposed_quantity_g CHECK (proposed_quantity_g >= 0 AND proposed_quantity_g NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE food_recognition_items ADD CONSTRAINT ck_v5_food_recognition_items_confidence CHECK (confidence >= 0 AND confidence NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE food_recognition_items ADD CHECK (confidence BETWEEN 0 AND 1);

ALTER TABLE food_recognition_items ADD CONSTRAINT ck_v5_food_recognition_items_review_status_enum CHECK (review_status IN ('PENDING','ACCEPTED','EDITED','REJECTED')) ;

ALTER TABLE food_recognition_items ADD CONSTRAINT ck_v5_food_recognition_items_confirmed_quantity_g CHECK (confirmed_quantity_g >= 0 AND confirmed_quantity_g NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE food_recognition_items ADD CONSTRAINT ck_v5_food_recognition_items_position CHECK (position > 0);

CREATE UNIQUE INDEX uq_v5_food_recognition_items_position ON food_recognition_items (recognition_id, position);

ALTER TABLE user_consents ADD CONSTRAINT fk_user_consents_user_id FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_user_consents_user_id ON user_consents (user_id);

ALTER TABLE user_consents ADD CONSTRAINT ck_v5_user_consents_purpose_enum CHECK (purpose IN ('AI_COACH','FOOD_RECOGNITION')) ;

ALTER TABLE user_consents ADD CONSTRAINT ck_v5_user_consents_policy_version CHECK (btrim(policy_version) <> '');

ALTER TABLE user_consents ADD CONSTRAINT ck_v5_user_consents_provider_scope CHECK (btrim(provider_scope) <> '');

ALTER TABLE ai_analysis_requests ADD CONSTRAINT fk_ai_analysis_requests_user_id FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_ai_analysis_requests_user_id ON ai_analysis_requests (user_id);

ALTER TABLE ai_analysis_requests ADD CONSTRAINT fk_ai_analysis_requests_consent_id FOREIGN KEY (consent_id) REFERENCES user_consents(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_ai_analysis_requests_consent_id ON ai_analysis_requests (consent_id);

ALTER TABLE ai_analysis_requests ADD CONSTRAINT fk_ai_analysis_requests_program_run_id FOREIGN KEY (program_run_id) REFERENCES program_runs(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_ai_analysis_requests_program_run_id ON ai_analysis_requests (program_run_id);

ALTER TABLE ai_analysis_requests ADD CONSTRAINT ck_v5_ai_analysis_requests_status_enum CHECK (status IN ('PENDING','RUNNING','SUCCEEDED','FAILED','CANCELLED')) ;

ALTER TABLE ai_analysis_requests ADD CONSTRAINT ck_v5_ai_analysis_requests_provider CHECK (btrim(provider) <> '');

ALTER TABLE ai_analysis_requests ADD CONSTRAINT ck_v5_ai_analysis_requests_model_version CHECK (btrim(model_version) <> '');

ALTER TABLE ai_analysis_requests ADD CONSTRAINT ck_v5_ai_analysis_requests_prompt_version CHECK (btrim(prompt_version) <> '');

ALTER TABLE ai_analysis_requests ADD CONSTRAINT ck_v5_ai_analysis_requests_context_revision CHECK (btrim(context_revision) <> '');

ALTER TABLE ai_analysis_requests ADD CONSTRAINT ck_ai_analysis_requests_context_summary_object CHECK (jsonb_typeof(context_summary) = 'object');

ALTER TABLE ai_recommendations ADD CONSTRAINT fk_ai_recommendations_analysis_request_id FOREIGN KEY (analysis_request_id) REFERENCES ai_analysis_requests(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_ai_recommendations_analysis_request_id ON ai_recommendations (analysis_request_id);

ALTER TABLE ai_recommendations ADD CONSTRAINT fk_ai_recommendations_scheduled_workout_id FOREIGN KEY (scheduled_workout_id) REFERENCES scheduled_workouts(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_ai_recommendations_scheduled_workout_id ON ai_recommendations (scheduled_workout_id);

ALTER TABLE ai_recommendations ADD CONSTRAINT fk_ai_recommendations_planned_set_id FOREIGN KEY (planned_set_id) REFERENCES planned_workout_sets(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_ai_recommendations_planned_set_id ON ai_recommendations (planned_set_id);

ALTER TABLE ai_recommendations ADD CONSTRAINT ck_v5_ai_recommendations_kind_enum CHECK (kind IN ('LOAD_CHANGE','EXERCISE_CHANGE','PROGRAM_DRAFT','EXPLANATION')) ;

ALTER TABLE ai_recommendations ADD CONSTRAINT ck_ai_recommendations_proposal_object CHECK (jsonb_typeof(proposal) = 'object');

ALTER TABLE ai_recommendations ADD CONSTRAINT ck_v5_ai_recommendations_explanation CHECK (btrim(explanation) <> '');

ALTER TABLE ai_recommendations ADD CONSTRAINT ck_v5_ai_recommendations_confidence CHECK (confidence >= 0 AND confidence NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));

ALTER TABLE ai_recommendations ADD CHECK (confidence BETWEEN 0 AND 1);

ALTER TABLE ai_recommendations ADD CONSTRAINT ck_v5_ai_recommendations_status_enum CHECK (status IN ('PROPOSED','ACCEPTED','REJECTED','EXPIRED','APPLIED','FAILED')) ;

ALTER TABLE ai_decisions ADD CONSTRAINT fk_ai_decisions_recommendation_id FOREIGN KEY (recommendation_id) REFERENCES ai_recommendations(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_ai_decisions_recommendation_id ON ai_decisions (recommendation_id);

ALTER TABLE ai_decisions ADD CONSTRAINT fk_ai_decisions_user_id FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_ai_decisions_user_id ON ai_decisions (user_id);

ALTER TABLE ai_decisions ADD CONSTRAINT ck_v5_ai_decisions_decision_enum CHECK (decision IN ('ACCEPT','REJECT')) ;

ALTER TABLE ai_decisions ADD CONSTRAINT ck_v5_ai_decisions_reason_code_enum CHECK (reason_code IN ('TOO_HARD','EQUIPMENT','WELLBEING','OTHER')) ;

CREATE UNIQUE INDEX uq_v5_ai_decisions_recommendation_id ON ai_decisions (recommendation_id);

ALTER TABLE recommendation_applications ADD CONSTRAINT fk_recommendation_applications_recommendation_id FOREIGN KEY (recommendation_id) REFERENCES ai_recommendations(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_recommendation_applications_recommendation_id ON recommendation_applications (recommendation_id);

ALTER TABLE recommendation_applications ADD CONSTRAINT fk_recommendation_applications_decision_id FOREIGN KEY (decision_id) REFERENCES ai_decisions(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_recommendation_applications_decision_id ON recommendation_applications (decision_id);

ALTER TABLE recommendation_applications ADD CONSTRAINT fk_recommendation_applications_template_version_id FOREIGN KEY (template_version_id) REFERENCES workout_template_versions(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_recommendation_applications_template_version_id ON recommendation_applications (template_version_id);

ALTER TABLE recommendation_applications ADD CONSTRAINT fk_recommendation_applications_program_version_id FOREIGN KEY (program_version_id) REFERENCES training_program_versions(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_recommendation_applications_program_version_id ON recommendation_applications (program_version_id);

ALTER TABLE recommendation_applications ADD CONSTRAINT fk_recommendation_applications_adjustment_id FOREIGN KEY (adjustment_id) REFERENCES workout_adjustments(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_recommendation_applications_adjustment_id ON recommendation_applications (adjustment_id);

ALTER TABLE recommendation_applications ADD CONSTRAINT ck_v5_recommendation_applications_status_enum CHECK (status IN ('APPLIED','FAILED')) ;

CREATE UNIQUE INDEX uq_v5_recommendation_applications_recommendation_id ON recommendation_applications (recommendation_id);

CREATE UNIQUE INDEX uq_v5_recommendation_applications_client_operation_id ON recommendation_applications (client_operation_id);

ALTER TABLE sync_operations ADD CONSTRAINT fk_sync_operations_user_id FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_sync_operations_user_id ON sync_operations (user_id);

ALTER TABLE sync_operations ADD CONSTRAINT ck_v5_sync_operations_device_id CHECK (btrim(device_id) <> '');

ALTER TABLE sync_operations ADD CONSTRAINT ck_v5_sync_operations_request_hash CHECK (btrim(request_hash) <> '');

ALTER TABLE sync_operations ADD CONSTRAINT ck_v5_sync_operations_operation_type CHECK (btrim(operation_type) <> '');

ALTER TABLE sync_operations ADD CONSTRAINT ck_v5_sync_operations_status_enum CHECK (status IN ('APPLIED','REJECTED')) ;

ALTER TABLE sync_operations ADD CONSTRAINT ck_sync_operations_result_reference_object CHECK (jsonb_typeof(result_reference) = 'object');

CREATE UNIQUE INDEX uq_v5_sync_operations_client_operation_id ON sync_operations (user_id, client_operation_id);

ALTER TABLE export_jobs ADD CONSTRAINT fk_export_jobs_user_id FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT;

CREATE INDEX ix_v5_export_jobs_user_id ON export_jobs (user_id);

ALTER TABLE export_jobs ADD CONSTRAINT ck_export_jobs_scope_object CHECK (jsonb_typeof(scope) = 'object');

ALTER TABLE export_jobs ADD CONSTRAINT ck_v5_export_jobs_status_enum CHECK (status IN ('PENDING','RUNNING','READY','FAILED','EXPIRED')) ;

CREATE UNIQUE INDEX uq_alias_normalized ON exercise_aliases(exercise_id, locale, lower(btrim(alias)));
CREATE UNIQUE INDEX uq_progression_scope ON progression_policies(program_version_id, planned_exercise_id) NULLS NOT DISTINCT;
CREATE UNIQUE INDEX uq_analytics_scope ON analytics_snapshots(user_id,metric_id,exercise_id,period_start,period_end,timezone,formula_version,filter_signature) NULLS NOT DISTINCT;
CREATE UNIQUE INDEX uq_recognition_meal ON food_recognitions(meal_entry_id) WHERE meal_entry_id IS NOT NULL;
CREATE UNIQUE INDEX uq_active_adjustment ON workout_adjustments(scheduled_workout_id,planned_set_id) WHERE status='ACTIVE';
CREATE UNIQUE INDEX uq_slot_attempt ON workout_sessions(scheduled_workout_id) WHERE scheduled_workout_id IS NOT NULL AND status IN ('IN_PROGRESS','PAUSED','COMPLETED');
CREATE UNIQUE INDEX uq_open_pause ON session_pauses(session_id) WHERE ended_at IS NULL;
CREATE UNIQUE INDEX uq_running_rest ON rest_intervals(session_id) WHERE status='RUNNING';
ALTER TABLE workout_sessions ADD CHECK (num_nonnulls(template_version_id,scheduled_workout_id)<=1);
ALTER TABLE session_exercises ADD CHECK (num_nonnulls(planned_exercise_id,template_exercise_id)<=1);
ALTER TABLE exercises ADD CHECK (difficulty_level IS NULL OR difficulty_level IN ('BEGINNER','INTERMEDIATE','ADVANCED'));
ALTER TABLE training_programs ADD CHECK (difficulty_level IS NULL OR difficulty_level IN ('BEGINNER','INTERMEDIATE','ADVANCED'));
ALTER TABLE foods ADD CHECK ((scope='SYSTEM' AND owner_user_id IS NULL) OR (scope='PRIVATE' AND owner_user_id IS NOT NULL));
ALTER TABLE media_files ADD CHECK ((scope='SYSTEM' AND owner_user_id IS NULL) OR (scope='PRIVATE' AND owner_user_id IS NOT NULL));
ALTER TABLE media_files ADD CHECK (size_bytes>0);
ALTER TABLE exercise_alternatives ADD CHECK (exercise_id<>alternative_exercise_id);
ALTER TABLE user_goals ADD CHECK (target_value IS NULL OR (metric_id IS NOT NULL AND target_unit IS NOT NULL));
ALTER TABLE recovery_checkins ADD CHECK (sleep_hours BETWEEN 0 AND 24);
ALTER TABLE recovery_checkins ADD CHECK (num_nonnulls(sleep_hours,sleep_quality,energy,fatigue,stress,notes)>0);
ALTER TABLE movement_discomforts ADD CHECK (exercise_id IS NOT NULL OR body_area IS NOT NULL);
ALTER TABLE food_recognition_items ADD CHECK (review_status NOT IN ('ACCEPTED','EDITED') OR confirmed_quantity_g>0);
ALTER TABLE meal_items ADD CHECK (quantity_g>0);
ALTER TABLE water_entries ADD CHECK (volume_ml>0);
ALTER TABLE body_measurements ADD CHECK (value>0);
ALTER TABLE hydration_targets ADD CHECK (volume_ml>0);
ALTER TABLE nutrition_targets ADD CHECK (coalesce(energy_kcal,0)+coalesce(protein_g,0)+coalesce(fat_g,0)+coalesce(carbs_g,0)>0);
ALTER TABLE nutrition_targets ADD CHECK (valid_to>valid_from);
ALTER TABLE hydration_targets ADD CHECK (valid_to>valid_from);
ALTER TABLE analytics_snapshots ADD CHECK (period_end>period_start);
ALTER TABLE schedule_changes ADD CHECK (from_date IS DISTINCT FROM to_date);
ALTER TABLE program_runs ADD CHECK ((status IN ('ACTIVE','PAUSED') AND finished_at IS NULL) OR (status IN ('COMPLETED','CANCELLED') AND finished_at>=started_at));
ALTER TABLE training_program_versions ADD CHECK ((status='DRAFT' AND published_at IS NULL) OR (status='PUBLISHED' AND published_at IS NOT NULL AND published_at>=created_at));
ALTER TABLE recommendation_applications ADD CHECK ((status='APPLIED' AND num_nonnulls(template_version_id,program_version_id,adjustment_id)=1 AND applied_at IS NOT NULL) OR (status='FAILED' AND num_nonnulls(template_version_id,program_version_id,adjustment_id)=0 AND applied_at IS NULL));
ALTER TABLE recommendation_applications ADD CHECK (error_code IS NULL OR status='FAILED');


ALTER TABLE template_sets ADD CHECK (set_method IN ('STRAIGHT','DROP','CLUSTER'));

ALTER TABLE planned_workout_sets ADD CHECK ((target_reps_min IS NULL AND target_reps_max IS NULL) OR (target_reps_min IS NOT NULL AND target_reps_max IS NOT NULL AND target_reps_min>0 AND target_reps_max>=target_reps_min));

ALTER TABLE planned_workout_sets ADD CHECK (set_method IN ('STRAIGHT','DROP','CLUSTER'));

ALTER TABLE session_sets ADD CHECK (set_method IN ('STRAIGHT','DROP','CLUSTER'));

ALTER TABLE template_set_segments ADD CHECK ((target_reps_min IS NULL AND target_reps_max IS NULL) OR (target_reps_min IS NOT NULL AND target_reps_max IS NOT NULL AND target_reps_min>0 AND target_reps_max>=target_reps_min));

ALTER TABLE planned_set_segments ADD CHECK ((target_reps_min IS NULL AND target_reps_max IS NULL) OR (target_reps_min IS NOT NULL AND target_reps_max IS NOT NULL AND target_reps_min>0 AND target_reps_max>=target_reps_min));

ALTER TABLE session_set_segments ADD CHECK ((target_reps_min IS NULL AND target_reps_max IS NULL) OR (target_reps_min IS NOT NULL AND target_reps_max IS NOT NULL AND target_reps_min>0 AND target_reps_max>=target_reps_min));

ALTER TABLE progression_policies ADD CHECK ((target_reps_min IS NULL AND target_reps_max IS NULL) OR (target_reps_min IS NOT NULL AND target_reps_max IS NOT NULL AND target_reps_min>0 AND target_reps_max>=target_reps_min));

ALTER TABLE workout_adjustments ADD CHECK ((target_reps_min IS NULL AND target_reps_max IS NULL) OR (target_reps_min IS NOT NULL AND target_reps_max IS NOT NULL AND target_reps_min>0 AND target_reps_max>=target_reps_min));

ALTER TABLE session_pauses ADD CHECK (ended_at>=started_at);

ALTER TABLE rest_intervals ADD CHECK (ends_at>=started_at);

ALTER TABLE rest_intervals ADD CHECK (ended_at>=started_at);

ALTER TABLE user_consents ADD CHECK (revoked_at>=granted_at);

ALTER TABLE ai_analysis_requests ADD CHECK (completed_at>=created_at);

ALTER TABLE food_recognitions ADD CHECK (completed_at>=created_at);

ALTER TABLE ai_recommendations ADD CHECK (expires_at>=created_at);

ALTER TABLE export_jobs ADD CHECK (completed_at>=created_at);

ALTER TABLE export_jobs ADD CHECK (expires_at>=created_at);

ALTER TABLE sync_operations ADD CHECK (expires_at>=created_at);