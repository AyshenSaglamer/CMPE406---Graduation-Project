from typing import Any

from fastapi import FastAPI, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

from services.error_service import (
    build_error_response,
)


def _http_error_code(
    status_code: int,
) -> str:
    """
    Convert common HTTP status codes into
    stable DiaMate error codes.
    """

    error_codes = {
        400: "BAD_REQUEST",
        401: "UNAUTHORIZED",
        403: "FORBIDDEN",
        404: "NOT_FOUND",
        409: "CONFLICT",
        413: "PAYLOAD_TOO_LARGE",
        422: "INVALID_INPUT",
        429: "RATE_LIMIT_EXCEEDED",
        500: "INTERNAL_ERROR",
        503: "SERVICE_UNAVAILABLE",
    }

    return error_codes.get(
        status_code,
        "HTTP_ERROR",
    )


async def http_exception_handler(
    request: Request,
    exc: HTTPException,
) -> JSONResponse:
    """
    Convert FastAPI HTTPException objects into
    the standard DiaMate error contract.
    """

    if isinstance(exc.detail, str):
        message = exc.detail

    else:
        message = "Request could not be completed."

    response = build_error_response(
        code=_http_error_code(
            exc.status_code
        ),
        message=message,
    )

    return JSONResponse(
        status_code=exc.status_code,
        content=response,
        headers=exc.headers,
    )


async def validation_exception_handler(
    request: Request,
    exc: RequestValidationError,
) -> JSONResponse:
    """
    Convert Pydantic/FastAPI request validation
    errors into the standard DiaMate format.

    Only a safe summary is returned to the client.
    """

    errors = exc.errors()

    message = "Request validation failed."
    field = None

    if errors:
        first_error = errors[0]

        error_message = first_error.get(
            "msg"
        )

        if isinstance(
            error_message,
            str,
        ):
            message = error_message

        location = first_error.get(
            "loc",
            (),
        )

        # Locations can look like:
        # ("body", "text")
        # ("body", "records", 0, "patient_id")
        #
        # We choose the last string component
        # that is not the generic "body" label.
        for item in reversed(location):
            if (
                isinstance(item, str)
                and item != "body"
            ):
                field = item
                break

    response = build_error_response(
        code="VALIDATION_ERROR",
        message=message,
        field=field,
    )

    return JSONResponse(
        status_code=422,
        content=response,
    )


async def unexpected_exception_handler(
    request: Request,
    exc: Exception,
) -> JSONResponse:
    """
    Handle otherwise unhandled exceptions.

    Internal exception details are deliberately
    not returned to the API client.
    """

    response = build_error_response(
        code="INTERNAL_ERROR",
        message=(
            "An unexpected internal error "
            "occurred."
        ),
    )

    return JSONResponse(
        status_code=500,
        content=response,
    )


def register_exception_handlers(
    app: FastAPI,
) -> None:
    """
    Register DiaMate's global API error handlers.
    """

    app.add_exception_handler(
        HTTPException,
        http_exception_handler,
    )

    app.add_exception_handler(
        RequestValidationError,
        validation_exception_handler,
    )

    app.add_exception_handler(
        Exception,
        unexpected_exception_handler,
    )
