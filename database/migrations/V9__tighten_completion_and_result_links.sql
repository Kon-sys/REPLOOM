-- Explicit NULL handling is important: a SQL CHECK also accepts UNKNOWN.
ALTER TABLE program_runs ADD CONSTRAINT ck_run_terminal_timestamp CHECK (
 (status IN ('ACTIVE','PAUSED') AND finished_at IS NULL)
 OR (status IN ('COMPLETED','CANCELLED') AND finished_at IS NOT NULL AND finished_at>=started_at)
);
ALTER TABLE food_recognition_items ADD CONSTRAINT ck_confirmed_recognition_mass CHECK (
 review_status NOT IN ('ACCEPTED','EDITED') OR (confirmed_quantity_g IS NOT NULL AND confirmed_quantity_g>0)
);
ALTER TABLE progression_policies ADD CHECK (weight_increment_kg>0);
ALTER TABLE progression_policies ADD CHECK (maximum_increment_kg>0);
ALTER TABLE progression_policies ADD CHECK (weight_increment_kg<=maximum_increment_kg);
ALTER TABLE export_jobs ADD CHECK (status<>'READY' OR (storage_key IS NOT NULL AND completed_at IS NOT NULL AND expires_at IS NOT NULL));

CREATE FUNCTION reploom_result_links_guard() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE parent_id uuid; actual_id uuid; source_status text; kind text; target_id uuid;
BEGIN
CASE TG_TABLE_NAME
WHEN 'personal_records' THEN
 SELECT se.exercise_id,ws.status INTO actual_id,source_status FROM session_sets ss JOIN session_exercises se ON se.id=ss.session_exercise_id JOIN workout_sessions ws ON ws.id=se.session_id WHERE ss.id=NEW.session_set_id AND ss.status='COMPLETED';
 IF actual_id IS DISTINCT FROM NEW.exercise_id OR source_status IS DISTINCT FROM 'COMPLETED' THEN RAISE EXCEPTION 'Record requires completed matching exercise' USING ERRCODE='23514'; END IF;
 IF NEW.session_segment_id IS NOT NULL THEN
  SELECT session_set_id INTO parent_id FROM session_set_segments WHERE id=NEW.session_segment_id AND status='COMPLETED';
  IF parent_id IS DISTINCT FROM NEW.session_set_id THEN RAISE EXCEPTION 'Record segment belongs to another set or is incomplete' USING ERRCODE='23514'; END IF;
 END IF;
WHEN 'session_media' THEN
 IF NOT EXISTS(SELECT 1 FROM media_files WHERE id=NEW.media_file_id AND scope='PRIVATE') THEN RAISE EXCEPTION 'Session photo must be private' USING ERRCODE='23514'; END IF;
WHEN 'ai_recommendations' THEN
 IF NEW.planned_set_id IS NOT NULL AND NEW.scheduled_workout_id IS NOT NULL THEN
  SELECT pe.planned_workout_id INTO parent_id FROM planned_workout_sets ps JOIN planned_workout_exercises pe ON pe.id=ps.planned_exercise_id WHERE ps.id=NEW.planned_set_id;
  SELECT planned_workout_id INTO target_id FROM scheduled_workouts WHERE id=NEW.scheduled_workout_id;
  IF parent_id IS DISTINCT FROM target_id THEN RAISE EXCEPTION 'Recommendation approach outside target workout' USING ERRCODE='23514'; END IF;
 END IF;
 IF NEW.kind='LOAD_CHANGE' AND num_nonnulls(NEW.planned_set_id,NEW.scheduled_workout_id,NEW.expected_target_revision)<>3 THEN RAISE EXCEPTION 'Load recommendation requires precise target and revision' USING ERRCODE='23514'; END IF;
WHEN 'recommendation_applications' THEN
 SELECT r.kind INTO kind FROM ai_recommendations r WHERE id=NEW.recommendation_id;
 IF NEW.status='APPLIED' AND NOT (
  (kind='LOAD_CHANGE' AND NEW.adjustment_id IS NOT NULL)
  OR (kind='PROGRAM_DRAFT' AND NEW.program_version_id IS NOT NULL)
  OR (kind='EXERCISE_CHANGE' AND num_nonnulls(NEW.template_version_id,NEW.program_version_id)=1)
 ) THEN RAISE EXCEPTION 'Result type does not match recommendation kind' USING ERRCODE='23514'; END IF;
END CASE;
RETURN NEW;
END $$;
CREATE TRIGGER f_result_links BEFORE INSERT OR UPDATE ON personal_records FOR EACH ROW EXECUTE FUNCTION reploom_result_links_guard();
CREATE TRIGGER f_result_links BEFORE INSERT OR UPDATE ON session_media FOR EACH ROW EXECUTE FUNCTION reploom_result_links_guard();
CREATE TRIGGER f_result_links BEFORE INSERT OR UPDATE ON ai_recommendations FOR EACH ROW EXECUTE FUNCTION reploom_result_links_guard();
CREATE TRIGGER f_result_links BEFORE INSERT OR UPDATE ON recommendation_applications FOR EACH ROW EXECUTE FUNCTION reploom_result_links_guard();
CREATE TRIGGER b_decision_immutable BEFORE UPDATE OR DELETE ON ai_decisions FOR EACH ROW EXECUTE FUNCTION reploom_audit_immutable();

CREATE FUNCTION reploom_validate_task_time() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
IF NEW.status IN ('SUCCEEDED','FAILED','CANCELLED') AND NEW.completed_at IS NULL THEN RAISE EXCEPTION 'Terminal task requires completion time' USING ERRCODE='23514'; END IF;
IF NEW.status IN ('PENDING','RUNNING') AND NEW.completed_at IS NOT NULL THEN RAISE EXCEPTION 'Active task has no completion time' USING ERRCODE='23514'; END IF;
RETURN NEW;
END $$;
CREATE TRIGGER f_task_time BEFORE INSERT OR UPDATE ON ai_analysis_requests FOR EACH ROW EXECUTE FUNCTION reploom_validate_task_time();
CREATE TRIGGER f_task_time BEFORE INSERT OR UPDATE ON food_recognitions FOR EACH ROW EXECUTE FUNCTION reploom_validate_task_time();
