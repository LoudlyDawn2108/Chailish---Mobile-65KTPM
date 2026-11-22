import pytest
from app.api.pronunciation import router

def test_pronunciation_router_prefix():
    assert router.prefix == "/pronunciation"
    assert "Pronunciation Assessment" in router.tags
