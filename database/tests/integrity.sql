\set ON_ERROR_STOP on
BEGIN;
CREATE FUNCTION pg_temp.ident(k text) RETURNS uuid LANGUAGE sql IMMUTABLE AS $$ SELECT md5('reploom-test-'||k)::uuid $$;
CREATE FUNCTION pg_temp.expect_error(q text,expected text) RETURNS void LANGUAGE plpgsql AS $$
DECLARE failed boolean:=false;
BEGIN
 BEGIN EXECUTE q; EXCEPTION WHEN OTHERS THEN IF SQLSTATE<>expected THEN RAISE EXCEPTION 'Expected %, got %: % (SQL: %)',expected,SQLSTATE,SQLERRM,q; END IF; failed:=true; END;
 IF NOT failed THEN RAISE EXCEPTION 'Expected rejection: %',q; END IF;
END $$;

INSERT INTO users(id,email,password_hash,display_name) VALUES
(pg_temp.ident('alice'),'db-test-alice@example.invalid','TEST-HASH-NOT-A-PASSWORD','Alice'),
(pg_temp.ident('bob'),'db-test-bob@example.invalid','TEST-HASH-NOT-A-PASSWORD','Bob');
SELECT pg_temp.expect_error($q$INSERT INTO users(email,password_hash,display_name) VALUES(' DB-TEST-ALICE@example.invalid ','x','duplicate')$q$,'23505');
INSERT INTO exercises(id,owner_user_id,name_ru,exercise_type,measurement_type,visibility) VALUES
(pg_temp.ident('press'),pg_temp.ident('alice'),'Test press','STRENGTH','WEIGHT_REPS','PRIVATE'),
(pg_temp.ident('plank'),pg_temp.ident('alice'),'Test plank','STATIC','TIME','PRIVATE'),
(pg_temp.ident('bob-exercise'),pg_temp.ident('bob'),'Private Bob','STRENGTH','REPS_ONLY','PRIVATE');
INSERT INTO workout_templates(id,owner_user_id,name) VALUES(pg_temp.ident('template'),pg_temp.ident('alice'),'Test template');
INSERT INTO workout_template_versions(id,template_id,version_number) VALUES(pg_temp.ident('v1'),pg_temp.ident('template'),1);
SELECT pg_temp.expect_error($q$INSERT INTO template_exercises(template_version_id,exercise_id,position) VALUES(pg_temp.ident('v1'),pg_temp.ident('bob-exercise'),1)$q$,'23514');
INSERT INTO template_exercises(id,template_version_id,exercise_id,position) VALUES(pg_temp.ident('te'),pg_temp.ident('v1'),pg_temp.ident('press'),1);
INSERT INTO template_sets(id,template_exercise_id,position,target_weight_kg,target_reps_min,target_reps_max) VALUES(pg_temp.ident('ts'),pg_temp.ident('te'),1,40,8,10);
SELECT pg_temp.expect_error($q$UPDATE template_sets SET target_duration_seconds=30 WHERE id=pg_temp.ident('ts')$q$,'23514');
UPDATE workout_template_versions SET status='PUBLISHED',published_at=clock_timestamp() WHERE id=pg_temp.ident('v1');
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
SELECT pg_temp.expect_error($q$UPDATE template_sets SET target_weight_kg=99 WHERE id=pg_temp.ident('ts')$q$,'23514');
SELECT pg_temp.expect_error($q$UPDATE workout_template_versions SET status='DRAFT',published_at=NULL WHERE id=pg_temp.ident('v1')$q$,'23514');
SELECT pg_temp.expect_error($q$DELETE FROM template_sets WHERE id=pg_temp.ident('ts')$q$,'23514');
INSERT INTO workout_template_versions(id,template_id,version_number) VALUES(pg_temp.ident('emptyv'),pg_temp.ident('template'),2);
SELECT pg_temp.expect_error($q$UPDATE workout_template_versions SET status='PUBLISHED',published_at=clock_timestamp() WHERE id=pg_temp.ident('emptyv'); SET CONSTRAINTS ALL IMMEDIATE$q$,'23514');

INSERT INTO workout_sessions(id,user_id,client_operation_id,name_snapshot,started_at) VALUES(pg_temp.ident('session'),pg_temp.ident('alice'),pg_temp.ident('operation'),'Test session',clock_timestamp()-interval '1 hour');
SELECT pg_temp.expect_error($q$INSERT INTO workout_sessions(user_id,client_operation_id,name_snapshot) VALUES(pg_temp.ident('alice'),gen_random_uuid(),'second active')$q$,'23505');
INSERT INTO session_exercises(id,session_id,exercise_id,name_snapshot,measurement_type_snapshot,position) VALUES(pg_temp.ident('se'),pg_temp.ident('session'),pg_temp.ident('press'),'Test press','WEIGHT_REPS',1);
SELECT pg_temp.expect_error($q$INSERT INTO session_sets(session_exercise_id,position,actual_reps,status,completed_at) VALUES(pg_temp.ident('se'),1,8,'COMPLETED',clock_timestamp())$q$,'23514');
INSERT INTO session_sets(id,session_exercise_id,position,actual_weight_kg,actual_reps,status,completed_at) VALUES(pg_temp.ident('ss'),pg_temp.ident('se'),1,40,8,'COMPLETED',clock_timestamp());
INSERT INTO session_exercises(id,session_id,exercise_id,name_snapshot,measurement_type_snapshot,position) VALUES(pg_temp.ident('time-se'),pg_temp.ident('session'),pg_temp.ident('plank'),'Test plank','TIME',2);
SELECT pg_temp.expect_error($q$INSERT INTO session_sets(session_exercise_id,position,actual_weight_kg,actual_reps,status,completed_at) VALUES(pg_temp.ident('time-se'),1,40,8,'COMPLETED',clock_timestamp())$q$,'23514');
INSERT INTO session_sets(session_exercise_id,position,actual_duration_seconds,status,completed_at) VALUES(pg_temp.ident('time-se'),1,30,'COMPLETED',clock_timestamp());
INSERT INTO session_sets(id,session_exercise_id,position,set_method,status,completed_at) VALUES(pg_temp.ident('drop'),pg_temp.ident('se'),2,'DROP','COMPLETED',clock_timestamp());
INSERT INTO session_set_segments(id,session_set_id,position,actual_weight_kg,actual_reps,status,completed_at) VALUES
(pg_temp.ident('drop1'),pg_temp.ident('drop'),1,40,8,'COMPLETED',clock_timestamp()),
(pg_temp.ident('drop2'),pg_temp.ident('drop'),2,30,8,'COMPLETED',clock_timestamp());
UPDATE workout_sessions SET status='PAUSED' WHERE id=pg_temp.ident('session');
UPDATE workout_sessions SET status='IN_PROGRESS' WHERE id=pg_temp.ident('session');
UPDATE workout_sessions SET status='COMPLETED',finished_at=clock_timestamp() WHERE id=pg_temp.ident('session');
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
SELECT pg_temp.expect_error($q$UPDATE session_sets SET actual_reps=100 WHERE id=pg_temp.ident('ss')$q$,'23514');
SELECT pg_temp.expect_error($q$UPDATE workout_sessions SET status='IN_PROGRESS',finished_at=NULL WHERE id=pg_temp.ident('session')$q$,'23514');

-- The runtime role sees only its user's private objects, without DDL privileges.
SELECT set_config('reploom.user_id',pg_temp.ident('alice')::text,true);
SET LOCAL ROLE reploom_app;
DO $$ BEGIN
IF (SELECT count(*) FROM users WHERE id=pg_temp.ident('bob'))<>0 THEN RAISE EXCEPTION 'RLS leaked user'; END IF;
IF (SELECT count(*) FROM exercises WHERE id=pg_temp.ident('bob-exercise'))<>0 THEN RAISE EXCEPTION 'RLS leaked exercise'; END IF;
IF (SELECT count(*) FROM workout_sessions WHERE id=pg_temp.ident('session'))<>1 THEN RAISE EXCEPTION 'Own session unavailable'; END IF;
END $$;
SELECT pg_temp.expect_error($q$INSERT INTO workout_templates(owner_user_id,name) VALUES(pg_temp.ident('bob'),'wrong owner')$q$,'42501');
SELECT reploom_correct_set(pg_temp.ident('ss'),' {"actual_reps":9}'::jsonb,'Correct mistyped reps',(SELECT revision FROM workout_sessions WHERE id=pg_temp.ident('session')));
SELECT reploom_correct_segment(pg_temp.ident('drop2'),' {"actual_reps":10}'::jsonb,'Correct segment reps',(SELECT revision FROM workout_sessions WHERE id=pg_temp.ident('session')));
RESET ROLE;
DO $$ BEGIN
IF (SELECT actual_reps FROM session_sets WHERE id=pg_temp.ident('ss'))<>9 THEN RAISE EXCEPTION 'Correction failed'; END IF;
IF (SELECT count(*) FROM session_revisions WHERE session_id=pg_temp.ident('session'))<>2 THEN RAISE EXCEPTION 'Missing audit'; END IF;
END $$;
SELECT pg_temp.expect_error($q$UPDATE session_revisions SET reason='erase' WHERE session_id=pg_temp.ident('session')$q$,'23514');
SELECT pg_temp.expect_error($q$SELECT reploom_correct_set(pg_temp.ident('ss'),' {"actual_reps":10}'::jsonb,'stale',1)$q$,'40001');

INSERT INTO nutrition_targets(user_id,valid_from,energy_kcal,source) VALUES(pg_temp.ident('alice'),'2026-01-01',2000,'MANUAL');
SELECT pg_temp.expect_error($q$INSERT INTO nutrition_targets(user_id,valid_from,energy_kcal,source) VALUES(pg_temp.ident('alice'),'2026-02-01',2200,'MANUAL')$q$,'23P01');
INSERT INTO meal_entries(id,user_id,eaten_at,local_date,timezone,meal_type) VALUES(pg_temp.ident('meal'),pg_temp.ident('alice'),'2026-11-12 12:00+00','2026-11-12','Europe/Moscow','LUNCH');
INSERT INTO foods(id,owner_user_id,scope,name,energy_kcal_100g) VALUES(pg_temp.ident('food'),pg_temp.ident('alice'),'PRIVATE','Test food',100);
INSERT INTO meal_items(id,meal_entry_id,food_id,name_snapshot,quantity_g,energy_kcal_100g_snapshot,position) VALUES(pg_temp.ident('item'),pg_temp.ident('meal'),pg_temp.ident('food'),'Food snapshot',200,100,1);
UPDATE foods SET energy_kcal_100g=999 WHERE id=pg_temp.ident('food');
DO $$ BEGIN IF (SELECT energy_kcal_100g_snapshot FROM meal_items WHERE id=pg_temp.ident('item'))<>100 THEN RAISE EXCEPTION 'Food history changed'; END IF; END $$;
SELECT pg_temp.expect_error($q$INSERT INTO water_entries(user_id,drunk_at,local_date,timezone,volume_ml) VALUES(pg_temp.ident('alice'),'2026-11-12 12:00+00','2026-11-11','Europe/Moscow',250)$q$,'23514');
INSERT INTO water_entries(user_id,drunk_at,local_date,timezone,volume_ml) VALUES(pg_temp.ident('alice'),'2026-11-12 12:00+00','2026-11-12','Europe/Moscow',250);

INSERT INTO training_programs(id,owner_user_id,name) VALUES(pg_temp.ident('program'),pg_temp.ident('alice'),'Test program');
INSERT INTO training_program_versions(id,program_id,version_number,duration_weeks,schedule_mode,status) VALUES(pg_temp.ident('pv'),pg_temp.ident('program'),1,1,'CALENDAR','DRAFT');
INSERT INTO program_blocks(id,program_version_id,name,block_type,position) VALUES(pg_temp.ident('block'),pg_temp.ident('pv'),'Block','DEVELOPMENT',1);
INSERT INTO program_weeks(id,program_block_id,week_number) VALUES(pg_temp.ident('week'),pg_temp.ident('block'),1);
INSERT INTO planned_workouts(id,program_week_id,name,position,day_of_week) VALUES(pg_temp.ident('planned'),pg_temp.ident('week'),'Workout',1,1);
INSERT INTO planned_workout_exercises(id,planned_workout_id,exercise_id,position) VALUES(pg_temp.ident('pe'),pg_temp.ident('planned'),pg_temp.ident('press'),1);
INSERT INTO planned_workout_sets(id,planned_exercise_id,position,set_category,set_method,effort_mode,target_reps_min,target_reps_max) VALUES(pg_temp.ident('ps'),pg_temp.ident('pe'),1,'WORKING','STRAIGHT','NORMAL',8,10);
UPDATE training_program_versions SET status='PUBLISHED',published_at=clock_timestamp() WHERE id=pg_temp.ident('pv');
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
INSERT INTO program_runs(id,user_id,program_version_id,started_at,status,timezone) VALUES(pg_temp.ident('run'),pg_temp.ident('alice'),pg_temp.ident('pv'),clock_timestamp(),'ACTIVE','Europe/Moscow');
INSERT INTO scheduled_workouts(id,program_run_id,planned_workout_id,scheduled_date,sequence_number,status,revision) VALUES(pg_temp.ident('slot'),pg_temp.ident('run'),pg_temp.ident('planned'),'2026-11-13',1,'PLANNED',1);
INSERT INTO workout_sessions(id,user_id,scheduled_workout_id,client_operation_id,name_snapshot) VALUES(pg_temp.ident('planned-session'),pg_temp.ident('alice'),pg_temp.ident('slot'),gen_random_uuid(),'Planned');
DO $$ BEGIN IF (SELECT status FROM scheduled_workouts WHERE id=pg_temp.ident('slot'))<>'IN_PROGRESS' THEN RAISE EXCEPTION 'Slot state not synchronized'; END IF; END $$;
UPDATE workout_sessions SET status='DISCARDED',finished_at=clock_timestamp() WHERE id=pg_temp.ident('planned-session');

INSERT INTO user_consents(id,user_id,purpose,policy_version,granted_at,provider_scope) VALUES(pg_temp.ident('consent'),pg_temp.ident('alice'),'AI_COACH','1',clock_timestamp(),'test-provider');
INSERT INTO ai_analysis_requests(id,user_id,consent_id,status,provider,model_version,prompt_version,context_revision,context_summary) VALUES(pg_temp.ident('request'),pg_temp.ident('alice'),pg_temp.ident('consent'),'PENDING','test-provider','test','1','1','{}');
UPDATE user_consents SET revoked_at=clock_timestamp() WHERE id=pg_temp.ident('consent');
SELECT pg_temp.expect_error($q$UPDATE ai_analysis_requests SET status='RUNNING' WHERE id=pg_temp.ident('request')$q$,'23514');
SELECT pg_temp.expect_error($q$UPDATE program_runs SET status='COMPLETED',finished_at=NULL WHERE id=pg_temp.ident('run')$q$,'23514');
SELECT pg_temp.expect_error($q$UPDATE ai_analysis_requests SET status='SUCCEEDED',completed_at=NULL WHERE id=pg_temp.ident('request')$q$,'23514');
DO $$ BEGIN
 PERFORM reploom_metrics('BODYWEIGHT_REPS','{"actual_reps":10}'::jsonb,'actual_',true);
 PERFORM reploom_metrics('ASSISTED_REPS','{"actual_reps":10,"actual_assistance_kg":20}'::jsonb,'actual_',true);
 PERFORM reploom_metrics('DISTANCE_TIME','{"actual_distance_meters":1000,"actual_duration_seconds":300}'::jsonb,'actual_',true);
 PERFORM reploom_metrics('REPS_ONLY','{"actual_reps":10}'::jsonb,'actual_',true);
 PERFORM reploom_metrics('WEIGHT_TIME','{"actual_weight_kg":20,"actual_duration_seconds":30}'::jsonb,'actual_',true);
END $$;
SELECT pg_temp.expect_error($q$SELECT reploom_metrics('ASSISTED_REPS','{"actual_reps":10,"actual_weight_kg":20}'::jsonb,'actual_',true)$q$,'23514');
SELECT pg_temp.expect_error($q$SELECT reploom_metrics('DISTANCE_TIME','{"actual_distance_meters":1000}'::jsonb,'actual_',true)$q$,'23514');
SET CONSTRAINTS ALL IMMEDIATE;
ROLLBACK;
\echo 'PASS: isolation, ownership, versions, measurements, history, audit, nutrition, cycles, consent'
