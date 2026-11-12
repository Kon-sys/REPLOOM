INSERT INTO training_goals(code,name,is_active) VALUES
('STRENGTH','Развитие силы',true),('HYPERTROPHY','Рост мышечной массы',true),('FAT_LOSS','Снижение массы тела',true),('ENDURANCE','Выносливость',true),('GENERAL_FITNESS','Общая физическая форма',true),('MOBILITY','Подвижность',true);
INSERT INTO metric_definitions(code,name,dimension,canonical_unit,direction,is_active) VALUES
('BODY_WEIGHT','Масса тела','MASS','kg','TARGET',true),('WAIST','Обхват талии','LENGTH','cm','TARGET',true),('EXTERNAL_WEIGHT','Внешний вес','MASS','kg','HIGHER',true),('REPETITIONS','Повторения','REPS','reps','HIGHER',true),('DISTANCE','Дистанция','LENGTH','m','HIGHER',true),('DURATION','Длительность','TIME','s','TARGET',true);
INSERT INTO equipment(name,category,is_active) VALUES ('Штанга','FREE_WEIGHT',true),('Гантели','FREE_WEIGHT',true),('Скамья','BENCH',true),('Турник','BODYWEIGHT',true),('Беговая дорожка','CARDIO',true);
INSERT INTO muscle_groups(name,sort_order) VALUES ('Грудь',1),('Спина',2),('Ноги',3),('Плечи',4),('Руки',5),('Кор',6);
