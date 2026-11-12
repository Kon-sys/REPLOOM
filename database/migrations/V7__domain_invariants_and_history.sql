
CREATE EXTENSION IF NOT EXISTS btree_gist;
ALTER TABLE nutrition_targets ADD CONSTRAINT ex_nutrition_period EXCLUDE USING gist(user_id WITH =,daterange(valid_from,valid_to,'[)') WITH &&);
ALTER TABLE hydration_targets ADD CONSTRAINT ex_hydration_period EXCLUDE USING gist(user_id WITH =,daterange(valid_from,valid_to,'[)') WITH &&);
ALTER TABLE session_pauses ADD CONSTRAINT ex_pause_period EXCLUDE USING gist(session_id WITH =,tstzrange(started_at,ended_at,'[)') WITH &&);
CREATE UNIQUE INDEX uq_template_group_position ON template_exercises(exercise_group_id,group_position) WHERE exercise_group_id IS NOT NULL;
CREATE UNIQUE INDEX uq_planned_group_position ON planned_workout_exercises(exercise_group_id,group_position) WHERE exercise_group_id IS NOT NULL;
CREATE UNIQUE INDEX uq_session_group_position ON session_exercises(exercise_group_id,group_position) WHERE exercise_group_id IS NOT NULL;
ALTER TABLE session_set_segments ADD CHECK ((status='COMPLETED' AND completed_at IS NOT NULL) OR (status IN ('PENDING','SKIPPED') AND completed_at IS NULL));
ALTER TABLE session_sets DROP CONSTRAINT ck_session_sets_completed_has_result;

CREATE SCHEMA reploom_private;
REVOKE ALL ON SCHEMA reploom_private FROM PUBLIC;
CREATE TABLE reploom_private.edit_context(transaction_id bigint PRIMARY KEY, session_id uuid NOT NULL);
CREATE FUNCTION reploom_edit_allowed(s uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
 SELECT EXISTS(SELECT 1 FROM reploom_private.edit_context WHERE transaction_id=txid_current() AND session_id=s)
$$;

CREATE FUNCTION reploom_metrics(s text,r jsonb,p text,required boolean) RETURNS void LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE k text; v numeric; allowed text[]; needs text[];
BEGIN
 CASE s
 WHEN 'WEIGHT_REPS' THEN allowed:=ARRAY['weight_kg','reps'];needs:=allowed;
 WHEN 'BODYWEIGHT_REPS' THEN allowed:=ARRAY['weight_kg','reps'];needs:=ARRAY['reps'];
 WHEN 'ASSISTED_REPS' THEN allowed:=ARRAY['assistance_kg','reps'];needs:=allowed;
 WHEN 'TIME' THEN allowed:=ARRAY['duration_seconds'];needs:=allowed;
 WHEN 'DISTANCE_TIME' THEN allowed:=ARRAY['distance_meters','duration_seconds'];needs:=allowed;
 WHEN 'REPS_ONLY' THEN allowed:=ARRAY['reps'];needs:=allowed;
 WHEN 'WEIGHT_TIME' THEN allowed:=ARRAY['weight_kg','duration_seconds'];needs:=allowed;
 ELSE RAISE EXCEPTION 'Unknown measurement scheme %',s USING ERRCODE='23514';
 END CASE;
 IF p='target_' THEN needs:=array_remove(array_remove(needs,'weight_kg'),'assistance_kg'); END IF;
 FOREACH k IN ARRAY ARRAY['weight_kg','assistance_kg','reps','duration_seconds','distance_meters'] LOOP
  IF k='reps' AND p='target_' THEN v:=(r->>'target_reps_min')::numeric; ELSE v:=(r->>(p||k))::numeric; END IF;
  IF v IS NOT NULL AND NOT k=ANY(allowed) THEN RAISE EXCEPTION 'Metric % not allowed for %',k,s USING ERRCODE='23514'; END IF;
  IF v IS NOT NULL AND (v<0 OR (k IN ('reps','duration_seconds','distance_meters') AND v=0)) THEN RAISE EXCEPTION 'Metric must be positive' USING ERRCODE='23514'; END IF;
  IF required AND k=ANY(needs) AND v IS NULL THEN RAISE EXCEPTION 'Missing % for %',k,s USING ERRCODE='23514'; END IF;
 END LOOP;
END $$;

CREATE FUNCTION reploom_version(t text,r jsonb) RETURNS uuid LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE parent text; col text; pr jsonb;
BEGIN
IF t IN ('workout_template_versions','training_program_versions') THEN RETURN (r->>'id')::uuid; END IF;
CASE t
WHEN 'template_exercise_groups' THEN parent:='workout_template_versions'; col:='template_version_id';
WHEN 'template_exercises' THEN parent:='workout_template_versions'; col:='template_version_id';
WHEN 'template_sets' THEN parent:='template_exercises'; col:='template_exercise_id';
WHEN 'template_set_segments' THEN parent:='template_sets'; col:='template_set_id';
WHEN 'program_goals' THEN parent:='training_program_versions'; col:='program_version_id';
WHEN 'program_blocks' THEN parent:='training_program_versions'; col:='program_version_id';
WHEN 'program_weeks' THEN parent:='program_blocks'; col:='program_block_id';
WHEN 'planned_workouts' THEN parent:='program_weeks'; col:='program_week_id';
WHEN 'planned_exercise_groups' THEN parent:='planned_workouts'; col:='planned_workout_id';
WHEN 'planned_workout_exercises' THEN parent:='planned_workouts'; col:='planned_workout_id';
WHEN 'planned_workout_sets' THEN parent:='planned_workout_exercises'; col:='planned_exercise_id';
WHEN 'planned_set_segments' THEN parent:='planned_workout_sets'; col:='planned_set_id';
WHEN 'progression_policies' THEN parent:='training_program_versions'; col:='program_version_id';
ELSE RETURN NULL; END CASE;
EXECUTE format('SELECT to_jsonb(x) FROM public.%I x WHERE id=$1',parent) INTO pr USING (r->>col)::uuid;
RETURN public.reploom_version(parent,pr);
END $$;

CREATE FUNCTION reploom_template_guard() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE r jsonb; v uuid; st text; newer integer; original integer;
BEGIN
r:=CASE WHEN TG_OP='DELETE' THEN to_jsonb(OLD) ELSE to_jsonb(NEW) END;
IF TG_TABLE_NAME IN ('workout_template_versions','training_program_versions') THEN
 IF TG_OP='INSERT' AND NEW.status<>'DRAFT' THEN RAISE EXCEPTION 'Create draft first' USING ERRCODE='23514'; END IF;
 IF TG_OP<>'INSERT' AND OLD.status='PUBLISHED' THEN RAISE EXCEPTION 'Published version is immutable' USING ERRCODE='23514'; END IF;
 IF TG_OP='UPDATE' AND NEW.version_number<>OLD.version_number THEN RAISE EXCEPTION 'Version number is immutable' USING ERRCODE='23514'; END IF;
 IF TG_OP<>'DELETE' AND NEW.based_on_version_id IS NOT NULL THEN
  EXECUTE format('SELECT version_number FROM %I WHERE id=$1',TG_TABLE_NAME) INTO original USING NEW.based_on_version_id;
  IF original>=NEW.version_number THEN RAISE EXCEPTION 'Base version must be earlier' USING ERRCODE='23514'; END IF;
 END IF;
ELSE
 v:=reploom_version(TG_TABLE_NAME,r);
 IF v IS NOT NULL THEN
  SELECT status INTO st FROM workout_template_versions WHERE id=v FOR UPDATE;
  IF NOT FOUND THEN SELECT status INTO st FROM training_program_versions WHERE id=v FOR UPDATE; END IF;
  IF st='PUBLISHED' THEN RAISE EXCEPTION 'Published contents are immutable' USING ERRCODE='23514'; END IF;
 END IF;
END IF;
RETURN CASE WHEN TG_OP='DELETE' THEN OLD ELSE NEW END;
END $$;

CREATE FUNCTION reploom_session_of(t text,r jsonb) RETURNS uuid LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE q jsonb;
BEGIN
 IF t='workout_sessions' THEN RETURN (r->>'id')::uuid; END IF;
 IF t IN ('session_exercises','session_exercise_groups','session_pauses','rest_intervals','session_media','session_revisions') THEN RETURN (r->>'session_id')::uuid; END IF;
 IF t='session_sets' THEN SELECT to_jsonb(x) INTO q FROM public.session_exercises x WHERE id=(r->>'session_exercise_id')::uuid; RETURN (q->>'session_id')::uuid; END IF;
 IF t='session_set_segments' THEN SELECT to_jsonb(x) INTO q FROM public.session_sets x WHERE id=(r->>'session_set_id')::uuid; RETURN public.reploom_session_of('session_sets',q); END IF;
 RETURN NULL;
END $$;

CREATE FUNCTION reploom_session_guard() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE r jsonb; sid uuid; st text;
BEGIN
r:=CASE WHEN TG_OP='DELETE' THEN to_jsonb(OLD) ELSE to_jsonb(NEW) END;
sid:=reploom_session_of(TG_TABLE_NAME,r);
IF TG_TABLE_NAME='workout_sessions' THEN
 IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Archive/discard sessions; do not delete history' USING ERRCODE='23514'; END IF;
 IF TG_OP='INSERT' AND NEW.status<>'IN_PROGRESS' THEN RAISE EXCEPTION 'Session must start IN_PROGRESS' USING ERRCODE='23514'; END IF;
 IF TG_OP='UPDATE' THEN
  IF OLD.status IN ('COMPLETED','DISCARDED') AND NOT reploom_edit_allowed(sid) THEN RAISE EXCEPTION 'Terminal session requires audited correction' USING ERRCODE='23514'; END IF;
  IF OLD.status IN ('COMPLETED','DISCARDED') AND NEW.status<>OLD.status THEN RAISE EXCEPTION 'Terminal status cannot change' USING ERRCODE='23514'; END IF;
  IF NEW.started_at IS DISTINCT FROM OLD.started_at OR NEW.template_version_id IS DISTINCT FROM OLD.template_version_id OR NEW.scheduled_workout_id IS DISTINCT FROM OLD.scheduled_workout_id OR NEW.client_operation_id IS DISTINCT FROM OLD.client_operation_id THEN RAISE EXCEPTION 'Session source/identity immutable' USING ERRCODE='23514'; END IF;
  NEW.revision:=OLD.revision+1;
 END IF;
ELSE
 SELECT status INTO st FROM workout_sessions WHERE id=sid FOR UPDATE;
 IF st IN ('COMPLETED','DISCARDED') AND NOT reploom_edit_allowed(sid) THEN RAISE EXCEPTION 'Terminal session contents are immutable' USING ERRCODE='23514'; END IF;
 IF TG_TABLE_NAME<>'session_revisions' THEN UPDATE workout_sessions SET revision=revision+1 WHERE id=sid; END IF;
END IF;
RETURN CASE WHEN TG_OP='DELETE' THEN OLD ELSE NEW END;
END $$;

CREATE FUNCTION reploom_metric_guard() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE r jsonb:=to_jsonb(NEW); e jsonb; par jsonb; scheme text; method text; segmented boolean:=false;
BEGIN
CASE TG_TABLE_NAME
WHEN 'template_sets' THEN SELECT to_jsonb(x) INTO e FROM template_exercises x WHERE id=NEW.template_exercise_id; SELECT measurement_type INTO scheme FROM exercises WHERE id=(e->>'exercise_id')::uuid;
WHEN 'planned_workout_sets' THEN SELECT to_jsonb(x) INTO e FROM planned_workout_exercises x WHERE id=NEW.planned_exercise_id; SELECT measurement_type INTO scheme FROM exercises WHERE id=(e->>'exercise_id')::uuid;
WHEN 'session_sets' THEN SELECT measurement_type_snapshot INTO scheme FROM session_exercises WHERE id=NEW.session_exercise_id;
WHEN 'template_set_segments' THEN SELECT to_jsonb(x) INTO par FROM template_sets x WHERE id=NEW.template_set_id; SELECT ex.measurement_type INTO scheme FROM exercises ex JOIN template_exercises te ON te.exercise_id=ex.id WHERE te.id=(par->>'template_exercise_id')::uuid;
WHEN 'planned_set_segments' THEN SELECT to_jsonb(x) INTO par FROM planned_workout_sets x WHERE id=NEW.planned_set_id; SELECT ex.measurement_type INTO scheme FROM exercises ex JOIN planned_workout_exercises pe ON pe.exercise_id=ex.id WHERE pe.id=(par->>'planned_exercise_id')::uuid;
WHEN 'session_set_segments' THEN SELECT to_jsonb(x) INTO par FROM session_sets x WHERE id=NEW.session_set_id; SELECT measurement_type_snapshot INTO scheme FROM session_exercises WHERE id=(par->>'session_exercise_id')::uuid;
END CASE;
IF par IS NOT NULL THEN
 IF par->>'set_method' NOT IN ('DROP','CLUSTER') THEN RAISE EXCEPTION 'Segments require DROP/CLUSTER' USING ERRCODE='23514'; END IF;
 method:=par->>'set_method';
ELSE method:=r->>'set_method'; segmented:=method IN ('DROP','CLUSTER'); END IF;
IF method IN ('DROP','CLUSTER') AND scheme NOT IN ('WEIGHT_REPS','BODYWEIGHT_REPS','ASSISTED_REPS','REPS_ONLY') THEN RAISE EXCEPTION 'Segmented method requires repetition scheme' USING ERRCODE='23514'; END IF;
IF segmented THEN
 IF num_nonnulls(r->>'target_weight_kg',r->>'target_assistance_kg',r->>'target_reps_min',r->>'target_duration_seconds',r->>'target_distance_meters',r->>'actual_weight_kg',r->>'actual_assistance_kg',r->>'actual_reps',r->>'actual_duration_seconds',r->>'actual_distance_meters')>0 THEN RAISE EXCEPTION 'Segmented parent must not duplicate metrics' USING ERRCODE='23514'; END IF;
ELSE
 PERFORM reploom_metrics(scheme,r,'target_',false);
 IF TG_TABLE_NAME IN ('session_sets','session_set_segments') THEN PERFORM reploom_metrics(scheme,r,'actual_',r->>'status'='COMPLETED'); END IF;
END IF;
RETURN NEW;
END $$;

CREATE FUNCTION reploom_relations_guard() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE r jsonb:=to_jsonb(NEW); p jsonb; q jsonb; v uuid; expected uuid; cnt bigint; scheme text;
BEGIN
IF TG_TABLE_NAME='exercises' AND TG_OP='UPDATE' THEN
 IF ROW(NEW.measurement_type,NEW.load_basis,NEW.visibility) IS DISTINCT FROM ROW(OLD.measurement_type,OLD.load_basis,OLD.visibility) THEN RAISE EXCEPTION 'Create a new exercise for a new measurement scheme/access scope' USING ERRCODE='23514'; END IF;
ELSIF TG_TABLE_NAME='muscle_groups' THEN
 -- Serialize hierarchy changes, including two concurrent inverse parent assignments.
 PERFORM pg_advisory_xact_lock(178401);
 IF NEW.parent_id IS NOT NULL AND EXISTS(WITH RECURSIVE ancestors AS (SELECT id,parent_id FROM muscle_groups WHERE id=NEW.parent_id UNION SELECT m.id,m.parent_id FROM muscle_groups m JOIN ancestors a ON m.id=a.parent_id) SELECT 1 FROM ancestors WHERE id=NEW.id) THEN RAISE EXCEPTION 'Muscle hierarchy cycle' USING ERRCODE='23514'; END IF;
ELSIF TG_TABLE_NAME IN ('template_exercises','planned_workout_exercises','session_exercises') THEN
 IF (r->>'exercise_group_id') IS NULL AND r->>'group_position' IS NOT NULL OR r->>'exercise_group_id' IS NOT NULL AND r->>'group_position' IS NULL THEN RAISE EXCEPTION 'Group and group_position must be set together' USING ERRCODE='23514'; END IF;
 IF TG_OP='UPDATE' AND (NEW.exercise_id IS DISTINCT FROM OLD.exercise_id) THEN RAISE EXCEPTION 'Replace exercise row instead of rewriting its metrics' USING ERRCODE='23514'; END IF;
 IF TG_TABLE_NAME='template_exercises' AND NEW.exercise_group_id IS NOT NULL THEN SELECT template_version_id INTO v FROM template_exercise_groups WHERE id=NEW.exercise_group_id; IF v<>NEW.template_version_id THEN RAISE EXCEPTION 'Group from another template' USING ERRCODE='23514'; END IF; END IF;
 IF TG_TABLE_NAME='planned_workout_exercises' AND r->>'exercise_group_id' IS NOT NULL THEN SELECT planned_workout_id INTO v FROM planned_exercise_groups WHERE id=(r->>'exercise_group_id')::uuid; IF v<>(r->>'planned_workout_id')::uuid THEN RAISE EXCEPTION 'Group from another workout' USING ERRCODE='23514'; END IF; END IF;
 IF TG_TABLE_NAME='session_exercises' THEN
  SELECT to_jsonb(x) INTO p FROM exercises x WHERE id=NEW.exercise_id;
  IF NEW.measurement_type_snapshot IS DISTINCT FROM p->>'measurement_type' OR NEW.load_basis_snapshot IS DISTINCT FROM p->>'load_basis' THEN RAISE EXCEPTION 'Measurement snapshot mismatch' USING ERRCODE='23514'; END IF;
  IF NEW.exercise_group_id IS NOT NULL THEN SELECT session_id INTO v FROM session_exercise_groups WHERE id=NEW.exercise_group_id; IF v<>NEW.session_id THEN RAISE EXCEPTION 'Group from another session' USING ERRCODE='23514'; END IF; END IF;
  SELECT to_jsonb(x) INTO q FROM workout_sessions x WHERE id=NEW.session_id;
  IF NEW.template_exercise_id IS NOT NULL THEN SELECT template_version_id INTO v FROM template_exercises WHERE id=NEW.template_exercise_id; IF v IS DISTINCT FROM (q->>'template_version_id')::uuid THEN RAISE EXCEPTION 'Wrong template source' USING ERRCODE='23514'; END IF; END IF;
  IF NEW.planned_exercise_id IS NOT NULL THEN SELECT planned_workout_id INTO v FROM planned_workout_exercises WHERE id=NEW.planned_exercise_id; SELECT planned_workout_id INTO expected FROM scheduled_workouts WHERE id=(q->>'scheduled_workout_id')::uuid; IF v IS DISTINCT FROM expected THEN RAISE EXCEPTION 'Wrong planned source' USING ERRCODE='23514'; END IF; END IF;
 END IF;
ELSIF TG_TABLE_NAME='program_weeks' THEN
 v:=reploom_version(TG_TABLE_NAME,r);
 IF EXISTS(SELECT 1 FROM program_weeks w JOIN program_blocks b ON b.id=w.program_block_id WHERE b.program_version_id=v AND w.week_number=NEW.week_number AND w.id<>NEW.id) THEN RAISE EXCEPTION 'Duplicate week in program version' USING ERRCODE='23514'; END IF;
ELSIF TG_TABLE_NAME='program_runs' THEN
 SELECT to_jsonb(x) INTO p FROM training_program_versions x WHERE id=NEW.program_version_id;
 IF p->>'status'<>'PUBLISHED' THEN RAISE EXCEPTION 'Run requires published program' USING ERRCODE='23514'; END IF;
ELSIF TG_TABLE_NAME='scheduled_workouts' THEN
 SELECT program_version_id INTO v FROM program_runs WHERE id=NEW.program_run_id;
 SELECT reploom_version('planned_workouts',to_jsonb(x)) INTO expected FROM planned_workouts x WHERE id=NEW.planned_workout_id;
 IF v IS DISTINCT FROM expected THEN RAISE EXCEPTION 'Workout outside run version' USING ERRCODE='23514'; END IF;
 IF NEW.scheduled_date IS NULL AND EXISTS(SELECT 1 FROM training_program_versions WHERE id=v AND schedule_mode='CALENDAR') THEN RAISE EXCEPTION 'Calendar slot requires date' USING ERRCODE='23514'; END IF;
ELSIF TG_TABLE_NAME='progression_policies' AND r->>'planned_exercise_id' IS NOT NULL THEN
 SELECT reploom_version('planned_workout_exercises',to_jsonb(x)) INTO v FROM planned_workout_exercises x WHERE id=NEW.planned_exercise_id;
 IF v<>NEW.program_version_id THEN RAISE EXCEPTION 'Progression target outside version' USING ERRCODE='23514'; END IF;
ELSIF TG_TABLE_NAME='workout_sessions' THEN
 IF NEW.template_version_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM workout_template_versions WHERE id=NEW.template_version_id AND status='PUBLISHED') THEN RAISE EXCEPTION 'Session requires published template' USING ERRCODE='23514'; END IF;
 IF NEW.scheduled_workout_id IS NOT NULL THEN
  SELECT to_jsonb(x) INTO p FROM scheduled_workouts x WHERE id=NEW.scheduled_workout_id FOR UPDATE;
  IF TG_OP='INSERT' AND p->>'status' NOT IN ('PLANNED','IN_PROGRESS') THEN RAISE EXCEPTION 'Slot not available' USING ERRCODE='23514'; END IF;
 END IF;
ELSIF TG_TABLE_NAME='rest_intervals' AND r->>'session_set_id' IS NOT NULL THEN
 SELECT reploom_session_of('session_sets',to_jsonb(x)) INTO v FROM session_sets x WHERE id=NEW.session_set_id;
 IF v<>NEW.session_id THEN RAISE EXCEPTION 'Rest set from another session' USING ERRCODE='23514'; END IF;
ELSIF TG_TABLE_NAME='workout_adjustments' THEN
 SELECT to_jsonb(x) INTO p FROM scheduled_workouts x WHERE id=NEW.scheduled_workout_id FOR UPDATE;
 SELECT pe.planned_workout_id INTO v FROM planned_workout_sets ps JOIN planned_workout_exercises pe ON pe.id=ps.planned_exercise_id WHERE ps.id=NEW.planned_set_id;
 IF v IS DISTINCT FROM (p->>'planned_workout_id')::uuid OR p->>'status'<>'PLANNED' THEN RAISE EXCEPTION 'Adjustment requires unstarted matching slot' USING ERRCODE='23514'; END IF;
 IF EXISTS(SELECT 1 FROM planned_workout_sets WHERE id=NEW.planned_set_id AND set_method<>'STRAIGHT') THEN RAISE EXCEPTION 'Segmented adjustment needs a new program version' USING ERRCODE='23514'; END IF;
ELSIF TG_TABLE_NAME IN ('body_measurements','user_goals','personal_records','analytics_snapshots') THEN
 IF r->>'metric_id' IS NOT NULL THEN SELECT to_jsonb(x) INTO p FROM metric_definitions x WHERE id=(r->>'metric_id')::uuid;
  IF coalesce(r->>'unit',r->>'target_unit',p->>'canonical_unit')<>p->>'canonical_unit' THEN RAISE EXCEPTION 'Unit does not match metric' USING ERRCODE='23514'; END IF;
 END IF;
ELSIF TG_TABLE_NAME='meal_entries' THEN IF NEW.local_date<>(NEW.eaten_at AT TIME ZONE NEW.timezone)::date THEN RAISE EXCEPTION 'Local food date mismatch' USING ERRCODE='23514'; END IF;
ELSIF TG_TABLE_NAME='water_entries' THEN IF NEW.local_date<>(NEW.drunk_at AT TIME ZONE NEW.timezone)::date THEN RAISE EXCEPTION 'Local water date mismatch' USING ERRCODE='23514'; END IF;
ELSIF TG_TABLE_NAME IN ('food_recognitions','ai_analysis_requests') THEN
 IF TG_OP='INSERT' OR (r->>'status'='RUNNING' AND OLD.status<>'RUNNING') THEN
 SELECT to_jsonb(x) INTO p FROM user_consents x WHERE id=(r->>'consent_id')::uuid;
 IF p->>'purpose'<>(CASE WHEN TG_TABLE_NAME='food_recognitions' THEN 'FOOD_RECOGNITION' ELSE 'AI_COACH' END) OR p->>'revoked_at' IS NOT NULL OR (p->>'granted_at')::timestamptz>clock_timestamp() OR p->>'provider_scope'<>r->>'provider' THEN RAISE EXCEPTION 'Consent missing/revoked/wrong provider' USING ERRCODE='23514'; END IF;
 END IF;
ELSIF TG_TABLE_NAME='recommendation_applications' THEN
 SELECT to_jsonb(x) INTO p FROM ai_decisions x WHERE id=NEW.decision_id;
 IF p->>'decision'<>'ACCEPT' OR (p->>'recommendation_id')::uuid<>NEW.recommendation_id THEN RAISE EXCEPTION 'Matching ACCEPT required' USING ERRCODE='23514'; END IF;
 SELECT to_jsonb(x) INTO q FROM ai_recommendations x WHERE id=NEW.recommendation_id;
 IF NEW.status='APPLIED' AND ((q->>'expires_at')::timestamptz<clock_timestamp() OR q->>'status' NOT IN ('ACCEPTED','APPLIED')) THEN RAISE EXCEPTION 'Recommendation expired/not accepted' USING ERRCODE='23514'; END IF;
 IF NEW.adjustment_id IS NOT NULL THEN
  SELECT to_jsonb(x) INTO p FROM workout_adjustments x WHERE id=NEW.adjustment_id;
  SELECT revision::text INTO scheme FROM scheduled_workouts WHERE id=(p->>'scheduled_workout_id')::uuid;
  IF (p->>'recommendation_id')::uuid IS DISTINCT FROM NEW.recommendation_id OR q->>'expected_target_revision' IS DISTINCT FROM scheme THEN RAISE EXCEPTION 'Stale or mismatched recommendation' USING ERRCODE='23514'; END IF;
 END IF;
END IF;
RETURN NEW;
END $$;
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON users FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON user_training_profiles FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON training_goals FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON metric_definitions FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON user_goals FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON user_equipment FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON user_training_days FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON exercises FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON exercise_aliases FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON muscle_groups FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON exercise_muscles FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON equipment FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON exercise_equipment FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON exercise_alternatives FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON media_files FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON exercise_media FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON workout_templates FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER b_version BEFORE INSERT OR UPDATE OR DELETE ON workout_template_versions FOR EACH ROW EXECUTE FUNCTION reploom_template_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON workout_template_versions FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER b_version BEFORE INSERT OR UPDATE OR DELETE ON template_exercise_groups FOR EACH ROW EXECUTE FUNCTION reploom_template_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON template_exercise_groups FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER b_version BEFORE INSERT OR UPDATE OR DELETE ON template_exercises FOR EACH ROW EXECUTE FUNCTION reploom_template_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON template_exercises FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER b_version BEFORE INSERT OR UPDATE OR DELETE ON template_sets FOR EACH ROW EXECUTE FUNCTION reploom_template_guard();
CREATE TRIGGER c_metrics BEFORE INSERT OR UPDATE ON template_sets FOR EACH ROW EXECUTE FUNCTION reploom_metric_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON template_sets FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER b_version BEFORE INSERT OR UPDATE OR DELETE ON template_set_segments FOR EACH ROW EXECUTE FUNCTION reploom_template_guard();
CREATE TRIGGER c_metrics BEFORE INSERT OR UPDATE ON template_set_segments FOR EACH ROW EXECUTE FUNCTION reploom_metric_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON template_set_segments FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON training_programs FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER b_version BEFORE INSERT OR UPDATE OR DELETE ON training_program_versions FOR EACH ROW EXECUTE FUNCTION reploom_template_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON training_program_versions FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER b_version BEFORE INSERT OR UPDATE OR DELETE ON program_goals FOR EACH ROW EXECUTE FUNCTION reploom_template_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON program_goals FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER b_version BEFORE INSERT OR UPDATE OR DELETE ON program_blocks FOR EACH ROW EXECUTE FUNCTION reploom_template_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON program_blocks FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER b_version BEFORE INSERT OR UPDATE OR DELETE ON program_weeks FOR EACH ROW EXECUTE FUNCTION reploom_template_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON program_weeks FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER b_version BEFORE INSERT OR UPDATE OR DELETE ON planned_workouts FOR EACH ROW EXECUTE FUNCTION reploom_template_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON planned_workouts FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER b_version BEFORE INSERT OR UPDATE OR DELETE ON planned_exercise_groups FOR EACH ROW EXECUTE FUNCTION reploom_template_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON planned_exercise_groups FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER b_version BEFORE INSERT OR UPDATE OR DELETE ON planned_workout_exercises FOR EACH ROW EXECUTE FUNCTION reploom_template_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON planned_workout_exercises FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER b_version BEFORE INSERT OR UPDATE OR DELETE ON planned_workout_sets FOR EACH ROW EXECUTE FUNCTION reploom_template_guard();
CREATE TRIGGER c_metrics BEFORE INSERT OR UPDATE ON planned_workout_sets FOR EACH ROW EXECUTE FUNCTION reploom_metric_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON planned_workout_sets FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER b_version BEFORE INSERT OR UPDATE OR DELETE ON planned_set_segments FOR EACH ROW EXECUTE FUNCTION reploom_template_guard();
CREATE TRIGGER c_metrics BEFORE INSERT OR UPDATE ON planned_set_segments FOR EACH ROW EXECUTE FUNCTION reploom_metric_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON planned_set_segments FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON program_runs FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON scheduled_workouts FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON schedule_changes FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER b_version BEFORE INSERT OR UPDATE OR DELETE ON progression_policies FOR EACH ROW EXECUTE FUNCTION reploom_template_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON progression_policies FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON workout_adjustments FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER b_session BEFORE INSERT OR UPDATE OR DELETE ON workout_sessions FOR EACH ROW EXECUTE FUNCTION reploom_session_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON workout_sessions FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER b_session BEFORE INSERT OR UPDATE OR DELETE ON session_exercise_groups FOR EACH ROW EXECUTE FUNCTION reploom_session_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON session_exercise_groups FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER b_session BEFORE INSERT OR UPDATE OR DELETE ON session_exercises FOR EACH ROW EXECUTE FUNCTION reploom_session_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON session_exercises FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER b_session BEFORE INSERT OR UPDATE OR DELETE ON session_sets FOR EACH ROW EXECUTE FUNCTION reploom_session_guard();
CREATE TRIGGER c_metrics BEFORE INSERT OR UPDATE ON session_sets FOR EACH ROW EXECUTE FUNCTION reploom_metric_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON session_sets FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER b_session BEFORE INSERT OR UPDATE OR DELETE ON session_set_segments FOR EACH ROW EXECUTE FUNCTION reploom_session_guard();
CREATE TRIGGER c_metrics BEFORE INSERT OR UPDATE ON session_set_segments FOR EACH ROW EXECUTE FUNCTION reploom_metric_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON session_set_segments FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER b_session BEFORE INSERT OR UPDATE OR DELETE ON session_pauses FOR EACH ROW EXECUTE FUNCTION reploom_session_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON session_pauses FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER b_session BEFORE INSERT OR UPDATE OR DELETE ON rest_intervals FOR EACH ROW EXECUTE FUNCTION reploom_session_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON rest_intervals FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER b_session BEFORE INSERT OR UPDATE OR DELETE ON session_media FOR EACH ROW EXECUTE FUNCTION reploom_session_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON session_media FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER b_session BEFORE INSERT OR UPDATE OR DELETE ON session_revisions FOR EACH ROW EXECUTE FUNCTION reploom_session_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON session_revisions FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON body_measurements FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON recovery_checkins FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON muscle_soreness FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON movement_discomforts FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON personal_records FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON analytics_snapshots FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON foods FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON meal_entries FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON meal_items FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON water_entries FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON nutrition_targets FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON hydration_targets FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON food_recognitions FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON food_recognition_items FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON user_consents FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON ai_analysis_requests FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON ai_recommendations FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON ai_decisions FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON recommendation_applications FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON sync_operations FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();
CREATE TRIGGER d_relations BEFORE INSERT OR UPDATE ON export_jobs FOR EACH ROW EXECUTE FUNCTION reploom_relations_guard();

CREATE FUNCTION reploom_check_plan_sets(ex_table text,set_table text,seg_table text,seg_fk text,container_col text,container uuid) RETURNS void LANGUAGE plpgsql AS $$
DECLARE e jsonb; st jsonb; seg jsonb; scheme text; count_sets int; count_segments int;
BEGIN
FOR e IN EXECUTE format('SELECT to_jsonb(x) FROM %I x WHERE %I=$1',ex_table,container_col) USING container LOOP
 SELECT measurement_type INTO scheme FROM exercises WHERE id=(e->>'exercise_id')::uuid;
 count_sets:=0;
 FOR st IN EXECUTE format('SELECT to_jsonb(x) FROM %I x WHERE %I=$1',set_table,CASE WHEN set_table='template_sets' THEN 'template_exercise_id' ELSE 'planned_exercise_id' END) USING (e->>'id')::uuid LOOP
  count_sets:=count_sets+1;
  IF st->>'set_method'='STRAIGHT' THEN
   EXECUTE format('SELECT count(*) FROM %I WHERE %I=$1',seg_table,seg_fk) INTO count_segments USING (st->>'id')::uuid;
   IF count_segments<>0 THEN RAISE EXCEPTION 'STRAIGHT cannot contain segments' USING ERRCODE='23514'; END IF;
   PERFORM reploom_metrics(scheme,st,'target_',true);
  ELSE
   count_segments:=0;
   FOR seg IN EXECUTE format('SELECT to_jsonb(x) FROM %I x WHERE %I=$1',seg_table,seg_fk) USING (st->>'id')::uuid LOOP
    PERFORM reploom_metrics(scheme,seg,'target_',true);count_segments:=count_segments+1;
   END LOOP;
   IF count_segments<2 THEN RAISE EXCEPTION 'Segmented plan requires 2+ segments' USING ERRCODE='23514'; END IF;
  END IF;
 END LOOP;
 IF count_sets=0 THEN RAISE EXCEPTION 'Published exercise requires sets' USING ERRCODE='23514'; END IF;
END LOOP;
END $$;

CREATE FUNCTION reploom_final_checks() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE r jsonb; p jsonb; v uuid; n bigint; w bigint; rec record; sid uuid; current_status text;
BEGIN
IF TG_TABLE_NAME='workout_template_versions' THEN
 SELECT to_jsonb(x) INTO r FROM workout_template_versions x WHERE id=NEW.id;
 IF r->>'status'='PUBLISHED' THEN
  IF NOT EXISTS(SELECT 1 FROM template_exercises WHERE template_version_id=NEW.id) THEN RAISE EXCEPTION 'Empty template cannot publish' USING ERRCODE='23514'; END IF;
  PERFORM reploom_check_plan_sets('template_exercises','template_sets','template_set_segments','template_set_id','template_version_id',NEW.id);
 END IF;
ELSIF TG_TABLE_NAME='training_program_versions' THEN
 SELECT to_jsonb(x) INTO r FROM training_program_versions x WHERE id=NEW.id;
 IF r->>'status'='PUBLISHED' THEN
  SELECT count(*),max(week_number) INTO n,w FROM program_weeks pw JOIN program_blocks pb ON pb.id=pw.program_block_id WHERE pb.program_version_id=NEW.id;
  IF n<>(r->>'duration_weeks')::bigint OR w<>n OR NOT EXISTS(SELECT 1 FROM program_blocks WHERE program_version_id=NEW.id) THEN RAISE EXCEPTION 'Program weeks must be 1..duration_weeks' USING ERRCODE='23514'; END IF;
  FOR rec IN SELECT pw.id FROM planned_workouts pw JOIN program_weeks w ON w.id=pw.program_week_id JOIN program_blocks b ON b.id=w.program_block_id WHERE b.program_version_id=NEW.id LOOP
   IF NOT EXISTS(SELECT 1 FROM planned_workout_exercises WHERE planned_workout_id=rec.id) THEN RAISE EXCEPTION 'Empty planned workout' USING ERRCODE='23514'; END IF;
   PERFORM reploom_check_plan_sets('planned_workout_exercises','planned_workout_sets','planned_set_segments','planned_set_id','planned_workout_id',rec.id);
  END LOOP;
  IF NOT FOUND THEN RAISE EXCEPTION 'Published program needs workouts' USING ERRCODE='23514'; END IF;
 END IF;
ELSIF TG_TABLE_NAME='workout_sessions' THEN
 SELECT status INTO current_status FROM workout_sessions WHERE id=NEW.id;
 IF current_status='COMPLETED' AND NOT EXISTS(SELECT 1 FROM session_sets ss JOIN session_exercises se ON se.id=ss.session_exercise_id WHERE se.session_id=NEW.id AND ss.status='COMPLETED') THEN RAISE EXCEPTION 'Completed session needs completed set' USING ERRCODE='23514'; END IF;
ELSIF TG_TABLE_NAME='session_sets' THEN
 SELECT to_jsonb(x) INTO r FROM session_sets x WHERE id=NEW.id;
 IF r->>'status'='COMPLETED' AND r->>'set_method' IN ('DROP','CLUSTER') AND NOT EXISTS(SELECT 1 FROM session_set_segments WHERE session_set_id=NEW.id AND status='COMPLETED') THEN RAISE EXCEPTION 'Completed segmented set needs completed segment' USING ERRCODE='23514'; END IF;
ELSIF TG_TABLE_NAME='meal_entries' THEN
 IF EXISTS(SELECT 1 FROM meal_entries WHERE id=NEW.id) AND NOT EXISTS(SELECT 1 FROM meal_items WHERE meal_entry_id=NEW.id) THEN RAISE EXCEPTION 'Meal needs an item' USING ERRCODE='23514'; END IF;
END IF;
RETURN NULL;
END $$;
CREATE CONSTRAINT TRIGGER z_final_check AFTER INSERT OR UPDATE ON workout_template_versions DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION reploom_final_checks();
CREATE CONSTRAINT TRIGGER z_final_check AFTER INSERT OR UPDATE ON training_program_versions DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION reploom_final_checks();
CREATE CONSTRAINT TRIGGER z_final_check AFTER INSERT OR UPDATE ON workout_sessions DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION reploom_final_checks();
CREATE CONSTRAINT TRIGGER z_final_check AFTER INSERT OR UPDATE ON session_sets DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION reploom_final_checks();
CREATE CONSTRAINT TRIGGER z_final_check AFTER INSERT OR UPDATE ON meal_entries DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION reploom_final_checks();

CREATE FUNCTION reploom_sync_slot() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
IF NEW.scheduled_workout_id IS NOT NULL THEN
 UPDATE scheduled_workouts SET status=CASE WHEN NEW.status='COMPLETED' THEN 'COMPLETED' WHEN NEW.status='DISCARDED' THEN 'PLANNED' ELSE 'IN_PROGRESS' END,revision=revision+1 WHERE id=NEW.scheduled_workout_id;
END IF;
RETURN NEW;
END $$;
CREATE TRIGGER e_sync_slot AFTER INSERT OR UPDATE OF status ON workout_sessions FOR EACH ROW EXECUTE FUNCTION reploom_sync_slot();

CREATE FUNCTION reploom_correct_set(set_id uuid,patch jsonb,reason text,expected_revision bigint) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE sid uuid; owner uuid; rev bigint; prev jsonb; curr jsonb; data public.session_sets; st text;
BEGIN
IF patch IS NULL OR jsonb_typeof(patch)<>'object' OR reason IS NULL OR btrim(reason)='' THEN RAISE EXCEPTION 'Patch and reason required' USING ERRCODE='23514'; END IF;
IF EXISTS(SELECT 1 FROM jsonb_object_keys(patch) k WHERE k NOT IN ('actual_weight_kg','actual_assistance_kg','actual_reps','actual_duration_seconds','actual_distance_meters','actual_rpe','actual_rir','notes')) THEN RAISE EXCEPTION 'Unsupported correction field' USING ERRCODE='23514'; END IF;
SELECT to_jsonb(x) INTO prev FROM public.session_sets x WHERE id=set_id;
IF prev IS NULL THEN RAISE EXCEPTION 'Set unavailable' USING ERRCODE='23503'; END IF;
sid:=public.reploom_session_of('session_sets',prev);
SELECT user_id,revision,status INTO owner,rev,st FROM public.workout_sessions WHERE id=sid FOR UPDATE;
IF owner IS DISTINCT FROM public.reploom_actor() OR st<>'COMPLETED' THEN RAISE EXCEPTION 'Own completed session required' USING ERRCODE='42501'; END IF;
IF rev<>expected_revision THEN RAISE EXCEPTION 'Revision conflict' USING ERRCODE='40001'; END IF;
INSERT INTO reploom_private.edit_context VALUES(txid_current(),sid);
SELECT * INTO data FROM jsonb_populate_record(NULL::public.session_sets,prev||patch);
UPDATE public.session_sets SET actual_weight_kg=data.actual_weight_kg,actual_assistance_kg=data.actual_assistance_kg,actual_reps=data.actual_reps,actual_duration_seconds=data.actual_duration_seconds,actual_distance_meters=data.actual_distance_meters,actual_rpe=data.actual_rpe,actual_rir=data.actual_rir,notes=data.notes WHERE id=set_id;
SELECT to_jsonb(x) INTO curr FROM public.session_sets x WHERE id=set_id;
SELECT revision INTO rev FROM public.workout_sessions WHERE id=sid;
INSERT INTO public.session_revisions(session_id,revision_number,changed_by,reason,change_summary,changed_at) VALUES(sid,rev,owner,reason,jsonb_build_object('set_id',set_id,'before',prev,'after',curr),clock_timestamp());
DELETE FROM public.personal_records WHERE session_set_id=set_id;
DELETE FROM public.analytics_snapshots WHERE user_id=owner;
SELECT revision INTO rev FROM public.workout_sessions WHERE id=sid;
DELETE FROM reploom_private.edit_context WHERE transaction_id=txid_current();
RETURN rev;
END $$;
REVOKE ALL ON FUNCTION reploom_correct_set(uuid,jsonb,text,bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION reploom_correct_set(uuid,jsonb,text,bigint),reploom_edit_allowed(uuid) TO reploom_app;
REVOKE INSERT,UPDATE,DELETE ON session_revisions FROM reploom_app;
CREATE FUNCTION reploom_audit_immutable() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'Audit records cannot change' USING ERRCODE='23514'; END $$;
CREATE TRIGGER b_audit_immutable BEFORE UPDATE OR DELETE ON session_revisions FOR EACH ROW EXECUTE FUNCTION reploom_audit_immutable();

CREATE FUNCTION reploom_touch_updated() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN NEW.updated_at:=clock_timestamp(); RETURN NEW; END $$;
CREATE TRIGGER z_touch BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION reploom_touch_updated();
CREATE TRIGGER z_touch BEFORE UPDATE ON workout_templates FOR EACH ROW EXECUTE FUNCTION reploom_touch_updated();
CREATE TRIGGER z_touch BEFORE UPDATE ON foods FOR EACH ROW EXECUTE FUNCTION reploom_touch_updated();

CREATE FUNCTION reploom_aggregate_checks() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE r jsonb; sid uuid; st text; v uuid; group_table text; ex_table text; container_col text; container uuid; g record; cnt bigint; lo bigint; hi bigint; slo bigint; shi bigint; parent jsonb; segcount bigint; completed bigint;
BEGIN
r:=CASE WHEN TG_OP='DELETE' THEN to_jsonb(OLD) ELSE to_jsonb(NEW) END;
sid:=reploom_session_of(TG_TABLE_NAME,r);
IF sid IS NOT NULL THEN
 SELECT status INTO st FROM workout_sessions WHERE id=sid;
 FOR parent IN SELECT to_jsonb(x) FROM session_sets x JOIN session_exercises e ON e.id=x.session_exercise_id WHERE e.session_id=sid LOOP
  SELECT count(*),count(*) FILTER(WHERE status='COMPLETED') INTO segcount,completed FROM session_set_segments WHERE session_set_id=(parent->>'id')::uuid;
  IF parent->>'set_method'='STRAIGHT' AND segcount>0 THEN RAISE EXCEPTION 'STRAIGHT set cannot have segments' USING ERRCODE='23514'; END IF;
  IF parent->>'set_method'<>'STRAIGHT' AND parent->>'status'='COMPLETED' AND (segcount<2 OR completed=0) THEN RAISE EXCEPTION 'Segmented set requires 2+ segments and completed result' USING ERRCODE='23514'; END IF;
 END LOOP;
 IF st<>'COMPLETED' THEN RETURN NULL; END IF;
 IF NOT EXISTS(SELECT 1 FROM session_sets ss JOIN session_exercises e ON e.id=ss.session_exercise_id WHERE e.session_id=sid AND ss.status='COMPLETED') THEN RAISE EXCEPTION 'Completed session needs result' USING ERRCODE='23514'; END IF;
 group_table:='session_exercise_groups';ex_table:='session_exercises';container_col:='session_id';container:=sid;
ELSIF TG_TABLE_NAME IN ('meal_items','meal_entries') THEN
 container:=CASE WHEN TG_TABLE_NAME='meal_items' THEN (r->>'meal_entry_id')::uuid ELSE (r->>'id')::uuid END;
 IF EXISTS(SELECT 1 FROM meal_entries WHERE id=container) AND NOT EXISTS(SELECT 1 FROM meal_items WHERE meal_entry_id=container) THEN RAISE EXCEPTION 'Meal cannot lose last item' USING ERRCODE='23514'; END IF;
 RETURN NULL;
ELSE
 v:=reploom_version(TG_TABLE_NAME,r);
 IF EXISTS(SELECT 1 FROM workout_template_versions WHERE id=v AND status='PUBLISHED') THEN group_table:='template_exercise_groups';ex_table:='template_exercises';container_col:='template_version_id';container:=v;
 ELSIF EXISTS(SELECT 1 FROM training_program_versions WHERE id=v AND status='PUBLISHED') THEN
  -- Program groups are checked per planned workout by calls scheduled from their rows.
  IF TG_TABLE_NAME='planned_exercise_groups' THEN container:=(r->>'planned_workout_id')::uuid;
  ELSIF TG_TABLE_NAME='planned_workout_exercises' THEN container:=(r->>'planned_workout_id')::uuid;
  ELSE RETURN NULL; END IF;
  group_table:='planned_exercise_groups';ex_table:='planned_workout_exercises';container_col:='planned_workout_id';
 ELSE RETURN NULL; END IF;
END IF;
FOR g IN EXECUTE format('SELECT id,position FROM %I WHERE %I=$1',group_table,container_col) USING container LOOP
 EXECUTE format('SELECT count(*),min(position),max(position),min(group_position),max(group_position) FROM %I WHERE exercise_group_id=$1',ex_table) INTO cnt,lo,hi,slo,shi USING g.id;
 IF cnt<2 OR hi-lo+1<>cnt OR lo<>g.position OR slo<>1 OR shi<>cnt THEN RAISE EXCEPTION 'Group must have 2+ contiguous, ordered exercises' USING ERRCODE='23514'; END IF;
END LOOP;
RETURN NULL;
END $$;

CREATE FUNCTION reploom_sync_ai_decision() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
 UPDATE ai_recommendations SET status=CASE WHEN NEW.decision='ACCEPT' THEN 'ACCEPTED' ELSE 'REJECTED' END WHERE id=NEW.recommendation_id;
 RETURN NEW;
END $$;
CREATE TRIGGER e_ai_decision AFTER INSERT ON ai_decisions FOR EACH ROW EXECUTE FUNCTION reploom_sync_ai_decision();
CREATE FUNCTION reploom_sync_ai_application() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
 UPDATE ai_recommendations SET status=NEW.status WHERE id=NEW.recommendation_id;
 RETURN NEW;
END $$;
CREATE TRIGGER e_ai_application AFTER INSERT OR UPDATE ON recommendation_applications FOR EACH ROW EXECUTE FUNCTION reploom_sync_ai_application();
CREATE CONSTRAINT TRIGGER z_aggregate_check AFTER INSERT OR UPDATE OR DELETE ON workout_templates DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION reploom_aggregate_checks();
CREATE CONSTRAINT TRIGGER z_aggregate_check AFTER INSERT OR UPDATE OR DELETE ON workout_template_versions DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION reploom_aggregate_checks();
CREATE CONSTRAINT TRIGGER z_aggregate_check AFTER INSERT OR UPDATE OR DELETE ON template_exercise_groups DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION reploom_aggregate_checks();
CREATE CONSTRAINT TRIGGER z_aggregate_check AFTER INSERT OR UPDATE OR DELETE ON template_exercises DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION reploom_aggregate_checks();
CREATE CONSTRAINT TRIGGER z_aggregate_check AFTER INSERT OR UPDATE OR DELETE ON template_sets DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION reploom_aggregate_checks();
CREATE CONSTRAINT TRIGGER z_aggregate_check AFTER INSERT OR UPDATE OR DELETE ON template_set_segments DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION reploom_aggregate_checks();
CREATE CONSTRAINT TRIGGER z_aggregate_check AFTER INSERT OR UPDATE OR DELETE ON planned_exercise_groups DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION reploom_aggregate_checks();
CREATE CONSTRAINT TRIGGER z_aggregate_check AFTER INSERT OR UPDATE OR DELETE ON planned_workout_exercises DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION reploom_aggregate_checks();
CREATE CONSTRAINT TRIGGER z_aggregate_check AFTER INSERT OR UPDATE OR DELETE ON workout_sessions DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION reploom_aggregate_checks();
CREATE CONSTRAINT TRIGGER z_aggregate_check AFTER INSERT OR UPDATE OR DELETE ON session_exercise_groups DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION reploom_aggregate_checks();
CREATE CONSTRAINT TRIGGER z_aggregate_check AFTER INSERT OR UPDATE OR DELETE ON session_exercises DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION reploom_aggregate_checks();
CREATE CONSTRAINT TRIGGER z_aggregate_check AFTER INSERT OR UPDATE OR DELETE ON session_sets DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION reploom_aggregate_checks();
CREATE CONSTRAINT TRIGGER z_aggregate_check AFTER INSERT OR UPDATE OR DELETE ON session_set_segments DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION reploom_aggregate_checks();
CREATE CONSTRAINT TRIGGER z_aggregate_check AFTER INSERT OR UPDATE OR DELETE ON session_pauses DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION reploom_aggregate_checks();
CREATE CONSTRAINT TRIGGER z_aggregate_check AFTER INSERT OR UPDATE OR DELETE ON rest_intervals DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION reploom_aggregate_checks();
CREATE CONSTRAINT TRIGGER z_aggregate_check AFTER INSERT OR UPDATE OR DELETE ON session_media DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION reploom_aggregate_checks();
CREATE CONSTRAINT TRIGGER z_aggregate_check AFTER INSERT OR UPDATE OR DELETE ON session_revisions DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION reploom_aggregate_checks();
CREATE CONSTRAINT TRIGGER z_aggregate_check AFTER INSERT OR UPDATE OR DELETE ON meal_entries DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION reploom_aggregate_checks();
CREATE CONSTRAINT TRIGGER z_aggregate_check AFTER INSERT OR UPDATE OR DELETE ON meal_items DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION reploom_aggregate_checks();
DO $$ DECLARE r record; BEGIN
FOR r IN SELECT to_jsonb(s) AS data,e.measurement_type AS scheme FROM template_sets s JOIN template_exercises t ON t.id=s.template_exercise_id JOIN exercises e ON e.id=t.exercise_id LOOP
 PERFORM reploom_metrics(r.scheme,r.data,'target_',false);
END LOOP;
FOR r IN SELECT to_jsonb(s) AS data,e.measurement_type_snapshot AS scheme FROM session_sets s JOIN session_exercises e ON e.id=s.session_exercise_id LOOP
 PERFORM reploom_metrics(r.scheme,r.data,'target_',false);
 PERFORM reploom_metrics(r.scheme,r.data,'actual_',r.data->>'status'='COMPLETED');
END LOOP;
END $$;
CREATE FUNCTION reploom_correct_segment(set_id uuid,patch jsonb,reason text,expected_revision bigint) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE sid uuid; owner uuid; rev bigint; prev jsonb; curr jsonb; data public.session_set_segments; st text;
BEGIN
IF patch IS NULL OR jsonb_typeof(patch)<>'object' OR reason IS NULL OR btrim(reason)='' THEN RAISE EXCEPTION 'Patch and reason required' USING ERRCODE='23514'; END IF;
IF EXISTS(SELECT 1 FROM jsonb_object_keys(patch) k WHERE k NOT IN ('actual_weight_kg','actual_assistance_kg','actual_reps','actual_duration_seconds','actual_distance_meters','actual_rpe','actual_rir','notes')) THEN RAISE EXCEPTION 'Unsupported correction field' USING ERRCODE='23514'; END IF;
SELECT to_jsonb(x) INTO prev FROM public.session_set_segments x WHERE id=set_id;
IF prev IS NULL THEN RAISE EXCEPTION 'Set unavailable' USING ERRCODE='23503'; END IF;
sid:=public.reploom_session_of('session_set_segments',prev);
SELECT user_id,revision,status INTO owner,rev,st FROM public.workout_sessions WHERE id=sid FOR UPDATE;
IF owner IS DISTINCT FROM public.reploom_actor() OR st<>'COMPLETED' THEN RAISE EXCEPTION 'Own completed session required' USING ERRCODE='42501'; END IF;
IF rev<>expected_revision THEN RAISE EXCEPTION 'Revision conflict' USING ERRCODE='40001'; END IF;
INSERT INTO reploom_private.edit_context VALUES(txid_current(),sid);
SELECT * INTO data FROM jsonb_populate_record(NULL::public.session_set_segments,prev||patch);
UPDATE public.session_set_segments SET actual_weight_kg=data.actual_weight_kg,actual_assistance_kg=data.actual_assistance_kg,actual_reps=data.actual_reps,actual_duration_seconds=data.actual_duration_seconds,actual_distance_meters=data.actual_distance_meters,actual_rpe=data.actual_rpe,actual_rir=data.actual_rir,notes=data.notes WHERE id=set_id;
SELECT to_jsonb(x) INTO curr FROM public.session_set_segments x WHERE id=set_id;
SELECT revision INTO rev FROM public.workout_sessions WHERE id=sid;
INSERT INTO public.session_revisions(session_id,revision_number,changed_by,reason,change_summary,changed_at) VALUES(sid,rev,owner,reason,jsonb_build_object('segment_id',set_id,'before',prev,'after',curr),clock_timestamp());
DELETE FROM public.personal_records WHERE session_segment_id=set_id;
DELETE FROM public.analytics_snapshots WHERE user_id=owner;
SELECT revision INTO rev FROM public.workout_sessions WHERE id=sid;
DELETE FROM reploom_private.edit_context WHERE transaction_id=txid_current();
RETURN rev;
END $$;
REVOKE ALL ON FUNCTION reploom_correct_segment(uuid,jsonb,text,bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION reploom_correct_segment(uuid,jsonb,text,bigint),reploom_edit_allowed(uuid) TO reploom_app;
REVOKE INSERT,UPDATE,DELETE ON session_revisions FROM reploom_app;
