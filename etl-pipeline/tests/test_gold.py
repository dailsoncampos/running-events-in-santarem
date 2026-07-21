from src.layers import gold


def test_event_summary_counts_runners_per_event(silver_data):
    result = gold.run()
    summary = result["event_summary"].set_index("event_id")

    assert summary.loc[1, "total_runners"] == 4
    assert summary.loc[2, "total_runners"] == 5
    assert summary.loc[3, "total_runners"] == 0  # not-yet-scraped event, no runners


def test_category_podium_ranks_within_event_and_category(silver_data):
    result = gold.run()
    podium = result["category_podium"]

    overall_event1 = podium[(podium["event_id"] == 1) & (podium["category"] == "OVERALL")]
    assert list(overall_event1.sort_values("rank")["bib_number"]) == ["101", "102"]
    assert list(overall_event1.sort_values("rank")["rank"]) == [1, 2]
