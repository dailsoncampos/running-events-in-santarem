def test_silver_dedupes_runners_by_event_bib_name(silver_data):
    runners = silver_data["runners"]
    assert not runners.duplicated(subset=["event_id", "bib_number", "name"]).any()


def test_silver_drops_runners_missing_required_fields(silver_data):
    runners = silver_data["runners"]
    assert not runners["name"].isna().any()
    assert not runners["position"].isna().any()
    assert len(runners) == 9  # 12 raw - 1 missing name - 1 missing position - 1 duplicate


def test_silver_parses_finish_time_to_seconds(silver_data):
    runners = silver_data["runners"]
    row = runners[(runners["event_id"] == 1) & (runners["bib_number"] == "101")].iloc[0]
    assert row["finish_time_seconds"] == 23 * 60 + 45
    assert row["pace_seconds_per_km"] == 4 * 60 + 45


def test_silver_events_have_expected_columns(silver_data):
    events = silver_data["events"]
    assert len(events) == 3
    assert {"event_id", "name", "event_date", "city"}.issubset(events.columns)
