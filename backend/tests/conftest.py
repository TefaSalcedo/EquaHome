import os
from collections.abc import Generator

import psycopg
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

os.environ.setdefault("EQUAHOME_JWT_SECRET", "test-secret")
os.environ["EQUAHOME_AI_PROVIDER"] = "mock"

import app.models  # noqa: E402,F401 — register tables
from app.core.db import Base, get_db  # noqa: E402
from app.main import app  # noqa: E402

ADMIN_URL = os.environ.get(
    "EQUAHOME_ADMIN_URL", "postgresql+psycopg://equahome:equahome@localhost:5432/postgres"
)
TEST_DB = "equahome_test"
TEST_URL = f"postgresql+psycopg://equahome:equahome@localhost:5432/{TEST_DB}"


@pytest.fixture(scope="session")
def test_engine():
    with psycopg.connect(ADMIN_URL.replace("+psycopg", ""), autocommit=True) as conn:
        conn.execute(f"DROP DATABASE IF EXISTS {TEST_DB} WITH (FORCE)")
        conn.execute(f"CREATE DATABASE {TEST_DB}")
    engine = create_engine(TEST_URL)
    Base.metadata.create_all(engine)
    yield engine
    engine.dispose()
    with psycopg.connect(ADMIN_URL.replace("+psycopg", ""), autocommit=True) as conn:
        conn.execute(f"DROP DATABASE IF EXISTS {TEST_DB} WITH (FORCE)")


@pytest.fixture()
def client(test_engine) -> Generator[TestClient, None, None]:
    TestingSession = sessionmaker(bind=test_engine, autoflush=False, expire_on_commit=False)

    def override_get_db():
        db = TestingSession()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()
    with test_engine.begin() as conn:
        for table in reversed(Base.metadata.sorted_tables):
            conn.execute(table.delete().execution_options(autocommit=True))
