"""Reject missing app coverage and enforce the combined line coverage policy."""

import json
import sys
from pathlib import Path


def app_coverage(report):
    """Return covered/executable lines for the single app target."""
    targets = [target for target in report["targets"] if target["name"] == "umalog.app"]
    if len(targets) != 1:
        raise ValueError("umalog.appのカバレッジ対象を一意に取得できません")
    covered = targets[0]["coveredLines"]
    executable = targets[0]["executableLines"]
    if type(covered) is not int or type(executable) is not int:
        raise ValueError("カバレッジの行数が整数ではありません")
    if not 0 <= covered <= executable or executable <= 0:
        raise ValueError("umalog.appの計測行数が不正または0です。結果を確認して再実行してください")
    return covered, executable


def check_reports(reports):
    """Validate each run before evaluating the merged report against 85%."""
    for report in reports:
        app_coverage(report)
    covered, executable = app_coverage(reports[-1])
    percentage = covered / executable * 100
    message = f"umalog.app 合算行カバレッジ: {percentage:.2f}% ({covered}/{executable}行)、基準: 85%以上"
    if covered * 100 < executable * 85:
        raise ValueError(message + " — 基準未達")
    return message + " — 合格"


def main():
    """Read unit/UI/merged xccov reports and return a failing status on invalid data."""
    try:
        if len(sys.argv) != 4:
            raise ValueError("unit、ui、mergedのJSONレポートを指定してください")
        reports = [json.loads(Path(path).read_text(encoding="utf-8")) for path in sys.argv[1:]]
        print(check_reports(reports))
    except (ValueError, KeyError, TypeError, OSError) as error:
        print(f"カバレッジ確認失敗: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
