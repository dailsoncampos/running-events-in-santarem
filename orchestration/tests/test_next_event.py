from datetime import date
from unittest.mock import MagicMock, patch

import pytest
import requests

from next_event import (
    _extract_array,
    _is_running_event,
    _parse_date,
    _parse_objects,
    next_event_date,
)

SAMPLE_HTML = """
<html><body>
<script>
var list_temp = [
  {nome: "Corrida de Rua Santarém", data: "10/07/2026", cidade: "Santarém"},
  {nome: "Circuito de Corrida", data: "30/08/2026", cidade: "Santarém"},
  {nome: "Ciclismo MTB", data: "15/09/2026", cidade: "Santarém"},
  {nome: "Corrida de Rua", data: "20/10/2026", cidade: "Belém"}
];
</script>
</body></html>
"""

HTML_WITH_NESTED_OBJECTS = """
<script>
var list_temp = [
  {nome: "Corrida de Rua", data: "30/08/2026", cidade: "Santarém", link: {resultados: {url: "http://x.com", label: "Resultados"}}},
  {nome: "Trail Run", data: "01/09/2026", cidade: "Santarém"}
];
</script>
"""


def _mock_response(html: str) -> MagicMock:
    mock = MagicMock()
    mock.text = html
    mock.raise_for_status.return_value = None
    return mock


class TestParseDate:
    def test_valid_brazilian_format(self):
        assert _parse_date("30/08/2026") == date(2026, 8, 30)

    def test_returns_none_for_iso_format(self):
        assert _parse_date("2026-08-30") is None

    def test_returns_none_for_garbage(self):
        assert _parse_date("not-a-date") is None

    def test_returns_none_for_none(self):
        assert _parse_date(None) is None

    def test_returns_none_for_empty_string(self):
        assert _parse_date("") is None


class TestIsRunningEvent:
    def test_accepts_running_event_in_santarem(self):
        assert _is_running_event("Circuito de Corrida de Rua", "Santarém") is True

    def test_rejects_event_from_other_city(self):
        assert _is_running_event("Corrida de Rua", "Belém") is False

    def test_city_check_is_case_insensitive(self):
        assert _is_running_event("Corrida de Rua", "SANTARÉM") is True

    @pytest.mark.parametrize("name", [
        "Ciclismo de Montanha",
        "Desafio Bike",
        "Desafio MTB Santarém",
        "Pedal Solidário",
        "Travessia a Nado do Rio Tapajós",
        "Natação Aberta",
        "Swimming Race",
        "Corrida de Trilha da Floresta",
        "Trail Run",
        "Triatlo de Santarém",
        "Triathlon Olímpico",
        "Duatlo",
    ])
    def test_rejects_excluded_modalities(self, name):
        assert _is_running_event(name, "Santarém") is False


class TestExtractArray:
    def test_extracts_array_from_script_tag(self):
        result = _extract_array(SAMPLE_HTML)
        assert result is not None
        assert "Corrida de Rua Santarém" in result

    def test_returns_none_when_no_list_temp(self):
        assert _extract_array("<html><body>nothing here</body></html>") is None

    def test_returns_none_for_empty_document(self):
        assert _extract_array("") is None


class TestParseObjects:
    def test_extracts_all_complete_objects(self):
        array = _extract_array(SAMPLE_HTML)
        events = _parse_objects(array)
        assert len(events) == 4
        assert events[0]["nome"] == "Corrida de Rua Santarém"
        assert events[0]["data"] == "10/07/2026"
        assert events[0]["cidade"] == "Santarém"

    def test_handles_nested_objects(self):
        array = _extract_array(HTML_WITH_NESTED_OBJECTS)
        events = _parse_objects(array)
        assert len(events) == 2
        assert events[0]["nome"] == "Corrida de Rua"

    def test_returns_empty_for_empty_array(self):
        assert _parse_objects("[]") == []


class TestNextEventDate:
    @patch("next_event.requests.get")
    def test_returns_soonest_future_running_event(self, mock_get):
        mock_get.return_value = _mock_response(SAMPLE_HTML)

        result = next_event_date(today=date(2026, 8, 9))

        assert result == date(2026, 8, 30)

    @patch("next_event.requests.get")
    def test_skips_past_events(self, mock_get):
        mock_get.return_value = _mock_response(SAMPLE_HTML)

        result = next_event_date(today=date(2026, 8, 9))

        assert result != date(2026, 7, 10)

    @patch("next_event.requests.get")
    def test_skips_non_running_events(self, mock_get):
        mock_get.return_value = _mock_response(SAMPLE_HTML)

        result = next_event_date(today=date(2026, 8, 9))

        assert result != date(2026, 9, 15)

    @patch("next_event.requests.get")
    def test_skips_events_from_other_cities(self, mock_get):
        mock_get.return_value = _mock_response(SAMPLE_HTML)

        result = next_event_date(today=date(2026, 8, 9))

        assert result != date(2026, 10, 20)

    @patch("next_event.requests.get")
    def test_returns_none_on_http_error(self, mock_get):
        mock_get.side_effect = requests.RequestException("connection refused")

        assert next_event_date(today=date(2026, 8, 9)) is None

    @patch("next_event.requests.get")
    def test_returns_none_when_no_upcoming_events(self, mock_get):
        mock_get.return_value = _mock_response(SAMPLE_HTML)

        assert next_event_date(today=date(2026, 12, 31)) is None

    @patch("next_event.requests.get")
    def test_returns_none_when_list_temp_missing(self, mock_get):
        mock_get.return_value = _mock_response("<html><body>no events</body></html>")

        assert next_event_date(today=date(2026, 8, 9)) is None
