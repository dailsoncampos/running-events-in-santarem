def test_bronze_preserves_raw_row_counts(bronze_data):
    assert len(bronze_data["events"]) == 3
    assert len(bronze_data["runners"]) == 12  # includes the duplicate row on purpose


def test_bronze_adds_ingestion_metadata(bronze_data):
    for df in bronze_data.values():
        assert "_source_file" in df.columns
        assert "_ingested_at" in df.columns
