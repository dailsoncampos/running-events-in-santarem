from datetime import date
from unittest.mock import patch

from check_and_run import main


class TestMain:
    @patch("check_and_run.santarem_pipeline")
    @patch("check_and_run.next_event_date")
    def test_runs_pipeline_on_day_after_event(self, mock_next_event, mock_pipeline):
        mock_next_event.return_value = date(2026, 8, 30)

        main(today=date(2026, 8, 31))

        mock_pipeline.assert_called_once()

    @patch("check_and_run.santarem_pipeline")
    @patch("check_and_run.next_event_date")
    def test_does_not_run_pipeline_on_event_day_itself(self, mock_next_event, mock_pipeline):
        mock_next_event.return_value = date(2026, 8, 30)

        main(today=date(2026, 8, 30))

        mock_pipeline.assert_not_called()

    @patch("check_and_run.santarem_pipeline")
    @patch("check_and_run.next_event_date")
    def test_does_not_run_pipeline_on_other_days(self, mock_next_event, mock_pipeline):
        mock_next_event.return_value = date(2026, 8, 30)

        main(today=date(2026, 8, 15))

        mock_pipeline.assert_not_called()

    @patch("check_and_run.santarem_pipeline")
    @patch("check_and_run.next_event_date")
    def test_exits_cleanly_when_no_next_event_found(self, mock_next_event, mock_pipeline):
        mock_next_event.return_value = None

        main(today=date(2026, 8, 31))

        mock_pipeline.assert_not_called()
