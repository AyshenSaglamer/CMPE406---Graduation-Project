package com.diamate.backend.ai;

import java.util.List;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * Answer of food-vision-service's POST /predict-food (ResNet50 trained on Food-101 + 24 Turkish dishes):
 * {"success": true, "model": "ResNet50", "predicted_food": "pizza", "confidence": 0.91,
 *  "top_predictions": [{"food": "pizza", "confidence": 0.91}, ...], "requires_user_confirmation": true}.
 * predicted_food / confidence repeat the first of top_predictions and are not read.
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public record FastApiFoodResult(Boolean success, String model,
        @JsonProperty("top_predictions") List<Prediction> topPredictions) {

    /** food: the model's class name, e.g. "apple_pie" or "lahmacun" (= food_catalog.name). */
    @JsonIgnoreProperties(ignoreUnknown = true)
    public record Prediction(String food, Double confidence) {
    }
}
