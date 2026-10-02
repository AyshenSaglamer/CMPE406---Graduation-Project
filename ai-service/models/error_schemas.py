from typing import Optional

from pydantic import BaseModel


class ErrorDetail(BaseModel):
    code: str
    message: str
    field: Optional[str] = None


class ErrorResponse(BaseModel):
    status: str = "ERROR"
    error: ErrorDetail
