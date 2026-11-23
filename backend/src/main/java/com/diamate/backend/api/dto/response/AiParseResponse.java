package com.diamate.backend.api.dto.response;

import java.util.List;

/**
 * What the AI assistant understood from the patient's text. Nothing is saved: the app shows the entries,
 * and after the patient confirms, it saves them with the log endpoints (source = AI_ASSISTANT).
 *
 * status: SUCCESS (at least one entry understood) or UNKNOWN (nothing understood; see message).
 */
public record AiParseResponse(String status, int resultCount, List<Entry> results, String message) {

    /**
     * One understood statement.
     * intent: LOG_GLUCOSE, LOG_INSULIN, LOG_MEAL or LOG_ACTIVITY.
     * status: SUCCESS, MISSING_VALUE or INVALID_VALUE (then "message" says what is wrong).
     * unit: "mg/dL", "units", "grams", or for activity "minutes", "hours", "km", ...
     * activity: the activity word found in the text (only for LOG_ACTIVITY).
     */
    public record Entry(String intent, String status, Double value, String unit, String activity, String message) {
    }
}
