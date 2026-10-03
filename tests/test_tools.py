import pytest
from pydantic import ValidationError

from app.mcp.schemas.tool_schemas import (
    CalculatorInput,
    GreetInput,
    SearchInput,
)


def test_calculator_input_valid():
    data = CalculatorInput(a=10, b=20)

    assert data.a == 10
    assert data.b == 20


def test_search_input_valid():
    data = SearchInput(query="Azure MCP")

    assert data.query == "Azure MCP"


def test_greet_input_valid():
    data = GreetInput(name="Sanjay")

    assert data.name == "Sanjay"


def test_calculator_rejects_large_value():
    with pytest.raises(ValidationError):
        CalculatorInput(
            a=10_000_001,
            b=10,
        )


def test_search_rejects_empty_query():
    with pytest.raises(ValidationError):
        SearchInput(query="")


def test_search_rejects_long_query():
    with pytest.raises(ValidationError):
        SearchInput(query="A" * 501)


def test_greet_rejects_empty_name():
    with pytest.raises(ValidationError):
        GreetInput(name="")
