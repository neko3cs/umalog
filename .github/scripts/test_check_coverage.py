"""Exercise coverage boundaries and missing measurement failures without Xcode."""

import unittest

from check_coverage import check_reports


def report(covered, executable=100):
    """Build the relevant xccov JSON fields."""
    return {"targets": [{"name": "umalog.app", "coveredLines": covered, "executableLines": executable}]}


class CoverageTests(unittest.TestCase):
    """Protect the gate against rounding and incomplete result bundles."""

    def test_combined_coverage_can_pass_when_individual_runs_are_below_threshold(self):
        self.assertIn("85.00%", check_reports([report(60), report(40), report(85)]))

    def test_value_rounding_to_85_percent_still_fails(self):
        with self.assertRaisesRegex(ValueError, "基準未達"):
            check_reports([report(60), report(40), report(84999, 100000)])

    def test_missing_measurement_fails_even_if_merged_coverage_passes(self):
        with self.assertRaisesRegex(ValueError, "計測行数"):
            check_reports([report(90), report(0, 0), report(95)])

    def test_dependency_coverage_cannot_substitute_for_app_coverage(self):
        dependency = {"targets": [{"name": "ZIPFoundation", "coveredLines": 100, "executableLines": 100}]}
        with self.assertRaisesRegex(ValueError, "一意"):
            check_reports([dependency, report(90), report(95)])

    def test_ambiguous_app_targets_fail(self):
        ambiguous = report(90)
        ambiguous["targets"] *= 2
        with self.assertRaisesRegex(ValueError, "一意"):
            check_reports([ambiguous, report(90), report(95)])

    def test_invalid_line_counts_fail(self):
        for covered, executable in [(101, 100), (-1, 100), (0, -1), (85.0, 100), (True, 100)]:
            with self.subTest(covered=covered, executable=executable), self.assertRaises(ValueError):
                check_reports([report(covered, executable), report(90), report(95)])


if __name__ == "__main__":
    unittest.main()
