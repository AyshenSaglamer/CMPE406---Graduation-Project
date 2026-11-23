package com.diamate.backend.api.dto.request;

import com.diamate.backend.entity.AlertStatus;

import jakarta.validation.constraints.NotNull;

/** Body of PATCH .../alerts/{alertId}. Only ACKNOWLEDGED and RESOLVED are accepted (checked in AlertService). */
public record AlertStatusRequest(@NotNull(message = "Status is required") AlertStatus status) {
}
