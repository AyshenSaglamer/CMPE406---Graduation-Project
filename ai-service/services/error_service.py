from typing import Dict, Optional


def build_error_response(
    *,
    code: str,
    message: str,
    field: Optional[str] = None,
) -> Dict:
    """
    Build a consistent API error response.

    This keeps error formatting independent
    from individual AI endpoints.
    """

    if not isinstance(code, str):
        raise ValueError(
            "Error code must be a string."
        )

    if not isinstance(message, str):
        raise ValueError(
            "Error message must be a string."
        )

    cleaned_code = code.strip()
    cleaned_message = message.strip()

    if not cleaned_code:
        raise ValueError(
            "Error code cannot be empty."
        )

    if not cleaned_message:
        raise ValueError(
            "Error message cannot be empty."
        )

    error = {
        "code": cleaned_code,
        "message": cleaned_message,
    }

    if field is not None:
        if not isinstance(field, str):
            raise ValueError(
                "Error field must be a string."
            )

        cleaned_field = field.strip()

        if not cleaned_field:
            raise ValueError(
                "Error field cannot be empty."
            )

        error["field"] = cleaned_field

    return {
        "status": "ERROR",
        "error": error,
    }
