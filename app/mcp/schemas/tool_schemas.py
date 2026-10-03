from pydantic import BaseModel, Field


class CalculatorInput(BaseModel):
    a: int = Field(
        description="First integer",
        ge=-1_000_000,
        le=1_000_000,
    )

    b: int = Field(
        description="Second integer",
        ge=-1_000_000,
        le=1_000_000,
    )


class SearchInput(BaseModel):
    query: str = Field(
        description="Search query",
        min_length=1,
        max_length=500,
    )


class GreetInput(BaseModel):
    name: str = Field(
        description="Name of the person to greet",
        min_length=1,
        max_length=100,
    )