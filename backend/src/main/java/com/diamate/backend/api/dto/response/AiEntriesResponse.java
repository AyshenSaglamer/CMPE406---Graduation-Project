package com.diamate.backend.api.dto.response;

import java.util.List;

import com.diamate.backend.api.dto.request.AiIntent;

/**
 * Answer of POST /api/v1/patients/{patientId}/ai-entries, in the order of the request.
 *
 * @param saved one item per entry: the log that was saved, in the same JSON shape as the matching log endpoint
 *              (GlucoseLogResponse, InsulinLogResponse, MealLogResponse or ActivityLogResponse). created = false
 *              when an entry with the same clientUuid had been saved before (nothing new was saved for it).
 */
public record AiEntriesResponse(int savedCount, List<Saved> saved) {

    public record Saved(AiIntent intent, long id, boolean created, Object log) {
    }
}
