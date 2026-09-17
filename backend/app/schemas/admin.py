from pydantic import BaseModel, Field


class ResetDataRequest(BaseModel):
    password: str = Field(min_length=1)


class ResetDataResponse(BaseModel):
    success: bool
    message: str
