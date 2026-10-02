from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient
from pydantic import BaseModel, Field

from services.exception_handlers import (
    register_exception_handlers,
)


app = FastAPI()

register_exception_handlers(app)


class DemoRequest(BaseModel):
    value: int = Field(gt=0)


@app.get("/demo-http-error")
def demo_http_error():
    raise HTTPException(
        status_code=503,
        detail="Demo service unavailable.",
    )


@app.post("/demo-validation")
def demo_validation(
    request: DemoRequest,
):
    return {
        "value": request.value,
    }


client = TestClient(
    app,
    raise_server_exceptions=False,
)


def test_http_exception_uses_standard_contract():
    response = client.get(
        "/demo-http-error"
    )

    assert response.status_code == 503

    data = response.json()

    assert data["status"] == "ERROR"

    assert (
        data["error"]["code"]
        == "SERVICE_UNAVAILABLE"
    )

    assert (
        data["error"]["message"]
        == "Demo service unavailable."
    )


def test_validation_error_uses_standard_contract():
    response = client.post(
        "/demo-validation",
        json={
            "value": 0,
        },
    )

    assert response.status_code == 422

    data = response.json()

    assert data["status"] == "ERROR"

    assert (
        data["error"]["code"]
        == "VALIDATION_ERROR"
    )

    assert (
        data["error"]["field"]
        == "value"
    )


def test_missing_field_uses_validation_contract():
    response = client.post(
        "/demo-validation",
        json={},
    )

    assert response.status_code == 422

    data = response.json()

    assert data["status"] == "ERROR"

    assert (
        data["error"]["code"]
        == "VALIDATION_ERROR"
    )

    assert (
        data["error"]["field"]
        == "value"
    )


def test_valid_request_still_works():
    response = client.post(
        "/demo-validation",
        json={
            "value": 5,
        },
    )

    assert response.status_code == 200

    assert response.json() == {
        "value": 5,
    }


def test_internal_error_hides_details():
    local_app = FastAPI()

    register_exception_handlers(
        local_app
    )

    @local_app.get("/crash")
    def crash():
        raise RuntimeError(
            "SECRET INTERNAL INFORMATION"
        )

    local_client = TestClient(
        local_app,
        raise_server_exceptions=False,
    )

    response = local_client.get(
        "/crash"
    )

    assert response.status_code == 500

    data = response.json()

    assert (
        data["error"]["code"]
        == "INTERNAL_ERROR"
    )

    assert (
        data["error"]["message"]
        == (
            "An unexpected internal "
            "error occurred."
        )
    )

    assert (
        "SECRET INTERNAL INFORMATION"
        not in response.text
    )
