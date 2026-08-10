"""Scrapes the CronoSantarém events page and returns the next upcoming
running event date in Santarém.

Used by check_and_run.py to decide whether today is a pipeline day.
"""
import logging
import re
from datetime import date, datetime

import requests

EVENTS_URL = "https://www.cronosantarem.com.br/eventos"

_EXCLUDED_TERMS = frozenset({
    "ciclismo", "bike", "mtb", "pedal",
    "natação", "nado", "travessia", "swimming",
    "trilha", "trail",
    "triatlo", "triathlon", "duatlo",
})

logger = logging.getLogger(__name__)


def _extract_array(html: str) -> str | None:
    m = re.search(r"list_temp\s*=\s*(\[.*?\]);", html, re.DOTALL)
    return m.group(1) if m else None


def _parse_objects(array_text: str) -> list[dict]:
    """Extract top-level JS objects from an array literal using brace counting."""
    events = []
    depth = 0
    start = None

    for i, ch in enumerate(array_text):
        if ch == "{":
            if depth == 0:
                start = i
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0 and start is not None:
                block = array_text[start : i + 1]
                ev = {}
                for key in ("nome", "data", "cidade"):
                    m = re.search(rf'\b{key}\s*:\s*"([^"]*)"', block)
                    if m:
                        ev[key] = m.group(1)
                if ev.keys() >= {"nome", "data", "cidade"}:
                    events.append(ev)
                start = None

    return events


def _parse_date(value: str | None) -> date | None:
    if not value:
        return None
    try:
        return datetime.strptime(value, "%d/%m/%Y").date()
    except ValueError:
        return None


def _is_running_event(nome: str, cidade: str) -> bool:
    if "santarém" not in cidade.lower():
        return False
    low = nome.lower()
    return not any(term in low for term in _EXCLUDED_TERMS)


def next_event_date(today: date | None = None) -> date | None:
    """Return the date of the soonest upcoming running event in Santarém, or None."""
    today = today or date.today()

    try:
        response = requests.get(EVENTS_URL, timeout=15)
        response.raise_for_status()
    except requests.RequestException as exc:
        logger.error("Failed to fetch events page: %s", exc)
        return None

    array_text = _extract_array(response.text)
    if not array_text:
        logger.warning("list_temp array not found on events page")
        return None

    upcoming = []
    for ev in _parse_objects(array_text):
        if not _is_running_event(ev["nome"], ev["cidade"]):
            continue
        d = _parse_date(ev["data"])
        if d is not None and d > today:
            upcoming.append(d)

    if not upcoming:
        logger.warning("No upcoming running events found in Santarém")
        return None

    return min(upcoming)
