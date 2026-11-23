-- DiaMate research schema: the row counts must match the CSV files (generated, do not edit)
\set ON_ERROR_STOP on
\echo
\echo === research schema: row count check ===
DO $$
DECLARE
    r record; n bigint; bad text := '';
BEGIN
    FOR r IN SELECT * FROM (VALUES
        ('patients', 166),
        ('records', 179),
        ('glucose_readings', 648177),
        ('meals', 10842),
        ('meal_items', 10788),
        ('insulin_doses', 531711),
        ('oral_medications', 3259),
        ('activity', 546899),
        ('ketones', 58),
        ('timeline', 702610),
        ('sources', 6),
        ('brfss_survey', 253680),
        ('food_classes', 101),
        ('food_images', 101000)
    ) AS v(tbl, expected) LOOP
        EXECUTE format('SELECT count(*) FROM research.%I', r.tbl) INTO n;
        IF n <> r.expected THEN bad := bad || format(' %s(%s, expected %s)', r.tbl, n, r.expected); END IF;
    END LOOP;
    IF bad <> '' THEN RAISE EXCEPTION 'research row counts differ:%', bad; END IF;
    RAISE NOTICE 'research schema: all 14 tables match the CSV row counts';
END $$;
-- no orphans (the foreign keys guarantee it; this is a readable double check)
SELECT (SELECT count(*) FROM research.glucose_readings g WHERE NOT EXISTS (SELECT 1 FROM research.patients p WHERE p.patient_id = g.patient_id)) AS orphan_glucose,
       (SELECT count(*) FROM research.meal_items i WHERE NOT EXISTS (SELECT 1 FROM research.meals m WHERE m.meal_id = i.meal_id)) AS orphan_meal_items,
       (SELECT count(*) FROM research.food_images f WHERE NOT EXISTS (SELECT 1 FROM research.food_classes c WHERE c.class_id = f.class_id)) AS orphan_food_images;
