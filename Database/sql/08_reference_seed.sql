-- DiaMate: reference data (needed by every installation, not demo-specific)
-- food_catalog is filled from the Food-101 class table (101 food classes the photo model can recognise).
-- Nutrition values are ROUGH ESTIMATES (is_verified = false): show them as "approximate" and never use them for insulin dosing.
\set ON_ERROR_STOP on

INSERT INTO food_catalog (name, display_name, kcal_per_100g, carbs_g_per_100g, default_serving_g, nutrition_source, is_verified, research_class_id)
SELECT class_name, display_name, kcal_per_100g_est, carbs_g_per_100g_est, typical_serving_g_est, nutrition_source, false, class_id
FROM research.food_classes
ORDER BY class_id
ON CONFLICT (name) DO NOTHING;
