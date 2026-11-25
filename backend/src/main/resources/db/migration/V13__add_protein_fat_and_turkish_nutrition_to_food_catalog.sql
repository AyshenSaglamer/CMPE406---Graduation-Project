-- V12: protein and fat in food_catalog, and rough nutrition for the 24 Turkish dishes of the photo model.
--
-- Food Vision week 2: POST /api/v1/ai/food and /ai/food/nutrition answer calories, carbohydrate, protein and fat
-- (meal_logs already has protein_g and fat_g). food_catalog had only kcal and carbs per 100 g.
--
-- ROUGH ESTIMATES, like V10 (is_verified stays false, nutrition_source 'rough_estimate_general_knowledge_verify_before_use'):
-- the app shows them as "approximate", the patient checks them, they are never used for insulin dosing. Protein is a
-- typical value for the dish; fat is what is left of the energy: (kcal - 4 x carbs - 4 x protein) / 9, never below 0,
-- so the four numbers of a food always agree with each other.
--
-- Only empty values are filled: a row someone has already given a protein value or a checked source keeps it.

ALTER TABLE food_catalog
    ADD COLUMN IF NOT EXISTS protein_g_per_100g numeric(5,1) CHECK (protein_g_per_100g >= 0 AND protein_g_per_100g <= 100),
    ADD COLUMN IF NOT EXISTS fat_g_per_100g     numeric(5,1) CHECK (fat_g_per_100g >= 0 AND fat_g_per_100g <= 100);

COMMENT ON COLUMN food_catalog.protein_g_per_100g IS 'Protein per 100 g. Rough estimate unless is_verified.';
COMMENT ON COLUMN food_catalog.fat_g_per_100g IS 'Fat per 100 g. Rough estimate unless is_verified.';

-- The 101 Food-101 foods (kcal and carbs from V10).
UPDATE food_catalog AS f
SET protein_g_per_100g = v.protein, fat_g_per_100g = v.fat
FROM (VALUES
    ('apple_pie', 2, 10.3),
    ('baby_back_ribs', 24, 18.8),
    ('baklava', 6, 25.1),
    ('beef_carpaccio', 21, 4.7),
    ('beef_tartare', 20, 9.6),
    ('beet_salad', 2, 3.3),
    ('beignets', 6, 17.6),
    ('bibimbap', 6, 3.2),
    ('bread_pudding', 6, 6.2),
    ('breakfast_burrito', 9, 9.6),
    ('bruschetta', 6, 6.9),
    ('caesar_salad', 5, 7.3),
    ('cannoli', 7, 16.9),
    ('caprese_salad', 9, 12.4),
    ('carrot_cake', 4, 20.4),
    ('ceviche', 14, 1.1),
    ('cheese_plate', 24, 30.2),
    ('cheesecake', 6, 21.3),
    ('chicken_curry', 13, 8.2),
    ('chicken_quesadilla', 14, 12),
    ('chicken_wings', 24, 20.2),
    ('chocolate_cake', 5, 16.7),
    ('chocolate_mousse', 4, 12.9),
    ('churros', 5, 24.4),
    ('clam_chowder', 4, 3.8),
    ('club_sandwich', 13, 10.9),
    ('crab_cakes', 14, 10.7),
    ('creme_brulee', 5, 19.6),
    ('croque_madame', 14, 13.8),
    ('cup_cakes', 4, 17.1),
    ('deviled_eggs', 11, 16.4),
    ('donuts', 5, 20),
    ('dumplings', 9, 7.8),
    ('edamame', 11, 4.4),
    ('eggs_benedict', 11, 14.4),
    ('escargots', 16, 2),
    ('falafel', 13, 16.7),
    ('filet_mignon', 28, 12),
    ('fish_and_chips', 12, 11.3),
    ('foie_gras', 11, 44),
    ('french_fries', 3, 14.9),
    ('french_onion_soup', 4, 3.6),
    ('french_toast', 8, 10),
    ('fried_calamari', 15, 11.1),
    ('fried_rice', 5, 5),
    ('frozen_yogurt', 4, 2.7),
    ('garlic_bread', 8, 15.3),
    ('gnocchi', 3, 1.6),
    ('greek_salad', 4, 8.2),
    ('grilled_cheese_sandwich', 12, 18.9),
    ('grilled_salmon', 22, 12.4),
    ('guacamole', 2, 12.3),
    ('gyoza', 9, 7.6),
    ('hamburger', 13, 11.3),
    ('hot_and_sour_soup', 3, 1.4),
    ('hot_dog', 10, 18),
    ('huevos_rancheros', 7, 7.3),
    ('hummus', 8, 9.1),
    ('ice_cream', 4, 10.9),
    ('lasagna', 9, 7.1),
    ('lobster_bisque', 5, 5.3),
    ('lobster_roll_sandwich', 12, 9.1),
    ('macaroni_and_cheese', 7, 6.9),
    ('macarons', 6, 15.1),
    ('miso_soup', 2, 1.2),
    ('mussels', 12, 2.4),
    ('nachos', 8, 17.6),
    ('omelette', 11, 11.9),
    ('onion_rings', 4, 18),
    ('oysters', 7, 2.7),
    ('pad_thai', 8, 4.4),
    ('paella', 8, 4.2),
    ('pancakes', 6, 8.7),
    ('panna_cotta', 3, 10.9),
    ('peking_duck', 19, 27.6),
    ('pho', 5, 0.9),
    ('pizza', 11, 10.4),
    ('pork_chop', 27, 13.6),
    ('poutine', 5, 12.2),
    ('prime_rib', 23, 22),
    ('pulled_pork_sandwich', 14, 8.9),
    ('ramen', 4, 2.4),
    ('ravioli', 8, 6),
    ('red_velvet_cake', 4, 18.2),
    ('risotto', 4, 4.2),
    ('samosa', 5, 14.2),
    ('sashimi', 22, 4.7),
    ('scallops', 20, 1.6),
    ('seaweed_salad', 1, 2.9),
    ('shrimp_and_grits', 9, 6),
    ('spaghetti_bolognese', 7, 4.4),
    ('spaghetti_carbonara', 8, 8.2),
    ('spring_rolls', 5, 8.2),
    ('steak', 25, 18.9),
    ('strawberry_shortcake', 4, 10),
    ('sushi', 6, 1.6),
    ('tacos', 9, 11.3),
    ('takoyaki', 7, 8.2),
    ('tiramisu', 5, 16.4),
    ('tuna_tartare', 22, 4.4),
    ('waffles', 7, 14.4)
) AS v (name, protein, fat)
WHERE f.name = v.name
  AND f.protein_g_per_100g IS NULL;

-- The 24 Turkish dishes (V9 added them without nutrition).
UPDATE food_catalog AS f
SET kcal_per_100g      = v.kcal,
    carbs_g_per_100g   = v.carbs,
    protein_g_per_100g = v.protein,
    fat_g_per_100g     = v.fat,
    default_serving_g  = v.serving,
    nutrition_source   = 'rough_estimate_general_knowledge_verify_before_use'
FROM (VALUES
    ('asure', 150, 30, 3, 2, 200),
    ('biber_dolmasi', 140, 17, 5, 5.8, 200),
    ('borek', 300, 28, 9, 16.9, 120),
    ('cig_kofte', 180, 33, 5, 3.1, 120),
    ('enginar', 90, 9, 2, 5.1, 200),
    ('et_sote', 160, 5, 18, 7.6, 200),
    ('gozleme', 260, 32, 9, 10.7, 180),
    ('hamsi', 220, 7, 18, 13.3, 150),
    ('hunkar_begendi', 160, 7, 11, 9.8, 300),
    ('icli_kofte', 260, 25, 10, 13.3, 100),
    ('ispanak', 80, 5, 4, 4.9, 200),
    ('izmir_kofte', 130, 9, 8, 6.9, 300),
    ('karniyarik', 140, 8, 6, 9.3, 250),
    ('kebap', 220, 2, 22, 13.8, 200),
    ('kisir', 150, 24, 4, 4.2, 150),
    ('kuru_fasulye', 120, 15, 7, 3.6, 250),
    ('lahmacun', 230, 30, 10, 7.8, 150),
    ('lokum', 350, 88, 0, 0, 30),
    ('manti', 210, 25, 9, 8.2, 250),
    ('mucver', 180, 12, 7, 11.6, 150),
    ('pirinc_pilavi', 160, 28, 3, 4, 180),
    ('simit', 320, 55, 10, 6.7, 100),
    ('taze_fasulye', 70, 7, 2, 3.8, 200),
    ('yaprak_sarma', 170, 22, 3, 7.8, 150)
) AS v (name, kcal, carbs, protein, fat, serving)
WHERE f.name = v.name
  AND f.nutrition_source = 'not_available'
  AND NOT f.is_verified;

