import pytest

from src.layers import bronze, silver


@pytest.fixture(scope="session")
def bronze_data():
    return bronze.run()


@pytest.fixture(scope="session")
def silver_data(bronze_data):
    return silver.run()
