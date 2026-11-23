package com.diamate.backend.entity;

/** glucose_logs.meal_context: when the reading was taken. Must match the CHECK constraint. */
public enum MealContext {
    FASTING,
    BEFORE_MEAL,
    AFTER_MEAL,
    BEDTIME,
    EXERCISE,
    OTHER
}
