from pydantic import BaseModel, Field, field_validator


class ParseRequest(BaseModel):
    text: str = Field(
        ...,
        min_length=1,
        max_length=500,
        description="Natural-language health log input.",
        examples=["My glucose is 125 and I took 5 units of insulin"],
    )

    @field_validator("text")
    @classmethod
    def validate_text(cls, value: str) -> str:
        cleaned_value = value.strip()

        if not cleaned_value:
            raise ValueError("Text must not be empty or whitespace.")

        return cleaned_value
