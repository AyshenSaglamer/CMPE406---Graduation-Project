package com.diamate.backend.api.dto.request;

import jakarta.validation.constraints.NotNull;

/** Body of PATCH /api/v1/admin/users/{userId}/status. */
public record AccountStatusRequest(@NotNull(message = "Active is required") Boolean active) {
}
