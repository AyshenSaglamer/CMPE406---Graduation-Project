import pytest

from services.error_service import (
    build_error_response,
)


def test_build_basic_error_response():
    result = build_error_response(
        code="INVALID_INPUT",
        message="Input is invalid.",
    )

    assert result == {
        "status": "ERROR",
        "error": {
            "code": "INVALID_INPUT",
            "message": "Input is invalid.",
        },
    }


def test_error_response_with_field():
    result = build_error_response(
        code="INVALID_GLUCOSE",
        message=(
            "Glucose must be greater "
            "than zero."
        ),
        field="glucose_mg_dl",
    )

    assert (
        result["error"]["field"]
        == "glucose_mg_dl"
    )


def test_code_is_trimmed():
    result = build_error_response(
        code="  INVALID_INPUT  ",
        message="Input is invalid.",
    )

    assert (
        result["error"]["code"]
        == "INVALID_INPUT"
    )


def test_message_is_trimmed():
    result = build_error_response(
        code="INVALID_INPUT",
        message="  Input is invalid.  ",
    )

    assert (
        result["error"]["message"]
        == "Input is invalid."
    )


def test_empty_code_rejected():
    with pytest.raises(
        ValueError,
        match="code cannot be empty",
    ):
        build_error_response(
            code="   ",
            message="Input is invalid.",
        )


def test_empty_message_rejected():
    with pytest.raises(
        ValueError,
        match="message cannot be empty",
    ):
        build_error_response(
            code="INVALID_INPUT",
            message="   ",
        )


def test_non_string_code_rejected():
    with pytest.raises(
        ValueError,
        match="code must be a string",
    ):
        build_error_response(
            code=123,
            message="Input is invalid.",
        )


def test_non_string_message_rejected():
    with pytest.raises(
        ValueError,
        match="message must be a string",
    ):
        build_error_response(
            code="INVALID_INPUT",
            message=123,
        )


def test_empty_field_rejected():
    with pytest.raises(
        ValueError,
        match="field cannot be empty",
    ):
        build_error_response(
            code="INVALID_INPUT",
            message="Input is invalid.",
            field="   ",
        )
