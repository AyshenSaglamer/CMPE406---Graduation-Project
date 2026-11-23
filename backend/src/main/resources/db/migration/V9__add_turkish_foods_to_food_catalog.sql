-- V9: the 24 Turkish dishes of the food photo model.
--
-- Ayşenur's ResNet50 (food-vision-service, models/food_classes.json) recognises 125 classes: the 101 Food-101 classes
-- that 08_reference_seed.sql already put into food_catalog, and the 24 TurkishFoods-25 classes below. Without these
-- rows POST /api/v1/ai/food could only show "lahmacun" as a bare class name.
--
-- No nutrition values on purpose (NULL, nutrition_source 'not_available'): there is no checked source for them yet, and
-- the app then asks the patient for the carbs instead of showing a made-up number. research_class_id is NULL because
-- research.food_classes holds only Food-101. ON CONFLICT: a catalog that already has one of the names keeps its row.

INSERT INTO food_catalog (name, display_name, nutrition_source, is_verified)
VALUES ('asure', 'Aşure', 'not_available', false),
       ('biber_dolmasi', 'Biber dolması', 'not_available', false),
       ('borek', 'Börek', 'not_available', false),
       ('cig_kofte', 'Çiğ köfte', 'not_available', false),
       ('enginar', 'Enginar', 'not_available', false),
       ('et_sote', 'Et sote', 'not_available', false),
       ('gozleme', 'Gözleme', 'not_available', false),
       ('hamsi', 'Hamsi', 'not_available', false),
       ('hunkar_begendi', 'Hünkâr beğendi', 'not_available', false),
       ('icli_kofte', 'İçli köfte', 'not_available', false),
       ('ispanak', 'Ispanak', 'not_available', false),
       ('izmir_kofte', 'İzmir köfte', 'not_available', false),
       ('karniyarik', 'Karnıyarık', 'not_available', false),
       ('kebap', 'Kebap', 'not_available', false),
       ('kisir', 'Kısır', 'not_available', false),
       ('kuru_fasulye', 'Kuru fasulye', 'not_available', false),
       ('lahmacun', 'Lahmacun', 'not_available', false),
       ('lokum', 'Lokum', 'not_available', false),
       ('manti', 'Mantı', 'not_available', false),
       ('mucver', 'Mücver', 'not_available', false),
       ('pirinc_pilavi', 'Pirinç pilavı', 'not_available', false),
       ('simit', 'Simit', 'not_available', false),
       ('taze_fasulye', 'Taze fasulye', 'not_available', false),
       ('yaprak_sarma', 'Yaprak sarma', 'not_available', false)
ON CONFLICT (name) DO NOTHING;
