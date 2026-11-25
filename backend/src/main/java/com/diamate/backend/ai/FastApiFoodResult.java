package com.diamate.backend.ai;

import java.util.List;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * Answer of food-vision-service's POST /predict-food (ResNet50 trained on Food-101 + 24 Turkish dishes, YOLO for the
 * food regions):
 * {"success": true, "model": "ResNet50", "predicted_food": "pizza", "confidence": 0.91,
 *  "top_predictions": [{"food": "pizza", "confidence": 0.91}, ...],
 *  "items": [{"box": [0.05, 0.17, 0.27, 0.81], "detector_label": "sandwich", "detector_confidence": 0.88,
 *             "top_predictions": [{"food": "hamburger", "confidence": 0.99}, ...]}, ...],
 *  "multiple_foods": true, "requires_user_confirmation": true}.
 * predicted_food / confidence repeat the first of top_predictions and are not read. items is missing (null) from an
 * older service and empty when the service found no separate food regions.
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public record FastApiFoodResult(Boolean success, String model,
        @JsonProperty("top_predictions") List<Prediction> topPredictions, List<Item> items) {

    /** For an older service (and tests) without items. */
    public FastApiFoodResult(Boolean success, String model, List<Prediction> topPredictions) {
        this(success, model, topPredictions, null);
    }

    /** food: the model's class name, e.g. "apple_pie" or "lahmacun" (= food_catalog.name). */
    @JsonIgnoreProperties(ignoreUnknown = true)
    public record Prediction(String food, Double confidence) {
    }

    /**
     * One food region of the photo. box: [x1, y1, x2, y2], each 0..1 of the photo's width / height. detectorLabel:
     * what the region detector saw ("bowl", "pizza"); the food itself is in topPredictions.
     */
    @JsonIgnoreProperties(ignoreUnknown = true)
    public record Item(List<Double> box, @JsonProperty("detector_label") String detectorLabel,
            @JsonProperty("top_predictions") List<Prediction> topPredictions) {
    }
}
