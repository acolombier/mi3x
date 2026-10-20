#!/usr/bin/env python3
"""Build and update a PR comment with E2E test results.

Called from .github/workflows/build.yml in the e2e-comment job.
Uses the `gh` CLI (pre-installed on GitHub Actions runners) for all API calls.

Environment variables:
  GITHUB_REPOSITORY      - owner/repo (required)
  GITHUB_RUN_ID          - workflow run ID (required)
  GITHUB_SERVER_URL      - GitHub server URL (required)
  GH_TOKEN               - GitHub token (required, auto-set from
                           ${{ github.token }})
  PR_NUMBER              - pull request number (required)
  RESULTS_DIR            - path to downloaded result artifacts
                           (default: results)
  VIDEO_DIR              - directory where recordings referenced by selected
                           scenarios are lazily downloaded to (default:
                           RESULTS_DIR). Pre-existing recordings are reused.
  SNIPPET_DIR            - directory to write extracted .mp4 snippets to
                           (default: snippets)
  SNIPPET_MAX_ATTACHMENTS- max number of clips to attach (default: 40)
  FFMPEG_BIN             - ffmpeg executable (default: ffmpeg)
  FFMPEG_JOBS            - number of concurrently running ffmpeg clip-cut
                           jobs (default: number of logical CPUs)
  BASE_REF               - git ref (e.g. FETCH_HEAD, origin/feat/qml) of the
                           PR base branch. Scenarios absent there are flagged
                           as new. Empty/unresolvable disables the flag.
  E2E_LOG_LEVEL          - log verbosity (DEBUG/INFO/WARNING/ERROR, default
                           INFO). All logging goes to stderr, so NO_GITHUB
                           stdout stays a clean comment body.

The comment is created or updated with the `gh` CLI
(`gh pr comment --edit-last --create-if-none`). For selected scenarios that
have a recording and timecodes, one .mp4 clip spanning the first to the last
attempt is cut with ffmpeg and attached with `gh --attach`, so it renders
inline in the error cell. Clips are posted as `![Preview](relpath)` markers
(the format `gh --attach` rewrites to the uploaded asset URL); a second pass
then re-edits the comment, converting those markers into inline `<video>`
players.

Scenarios that do not exist in BASE_REF are highlighted: their name is
prefixed with "*(New)*", they are sorted to the top of their feature table,
and their clip is attached so reviewers can watch them.

Note: `gh --attach` only accepts OAuth/PAT tokens (gho_/ghp_/github_pat_/
ghu_); the default Actions token (${{ github.token }}, ghs_) is rejected. In
that case the script transparently falls back to plain artifact links.

Recordings are not pulled up front: only the (few) recordings actually
referenced by the selected scenarios are downloaded lazily via the Actions
artifact REST API, in parallel with up to FFMPEG_JOBS workers; a recording
already present in VIDEO_DIR is reused (retry-safe). A recording download
that fails only drops the video from the affected scenarios, never the
comment itself.

When NO_GITHUB=1 is set, the script runs in offline mode: it reads results
from RESULTS_DIR, prints the generated comment body to stdout, and skips all
GitHub API calls (using local files for video URLs).
"""

import enum
import json
import logging
import os
import pathlib
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import time
import zipfile
from typing import NamedTuple

TITLE_MARKER = "<!-- mixxx-e2e-results -->"

# Outcomes that indicate a real problem (as opposed to expected failure/flaky).
FAILURE_OUTCOMES = ("failed", "error")

# Where the Gherkin features live, used to diff scenarios against BASE_REF.
FEATURES_DIR = "src/test/behave/features"

SLUG_NAMES = {
    "ubuntu-jammy": "Ubuntu 26.04",
    "macos-macosintel": "macOS 15 x64",
    "windows-win64": "Windows Server 2025 VS2026 x64",
    "windows-winarm": "Windows 11 VS2026 ARM64",
}

LOG = logging.getLogger("mixxx.e2e_comment")


def _configure_logging():
    """Route logs to stderr so stdout stays the comment body in NO_GITHUB
    mode.
    """
    if LOG.handlers:
        return
    level_name = os.environ.get("E2E_LOG_LEVEL", "INFO").upper()
    handler = logging.StreamHandler(sys.stderr)
    handler.setFormatter(
        logging.Formatter(
            "%(asctime)s %(levelname)-7s %(message)s", "%Y-%m-%dT%H:%M:%S"
        )
    )
    LOG.addHandler(handler)
    LOG.setLevel(getattr(logging, level_name, logging.INFO))
    LOG.propagate = False


_configure_logging()


def fmt_cmd(cmd):
    """Render a subprocess argv as a copy-pasteable shell command."""
    return " ".join(shlex.quote(str(part)) for part in cmd)


def run_logged(cmd, check=False, input_text=None):
    """Run a subprocess, logging the exact command line and how it ended."""
    LOG.info("exec: %s", fmt_cmd(cmd))
    started = time.monotonic()
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=check,
            input=input_text,
        )
    except subprocess.CalledProcessError as exc:
        LOG.error(
            "exit=%s after %.2fs: %s%s",
            exc.returncode,
            time.monotonic() - started,
            fmt_cmd(cmd),
            f"\nstderr: {exc.stderr.strip()}" if exc.stderr else "",
        )
        raise
    LOG.debug(
        "exit=%d after %.2fs (stdout=%dB, stderr=%dB)",
        result.returncode,
        time.monotonic() - started,
        len(result.stdout or ""),
        len(result.stderr or ""),
    )
    if result.stderr.strip():
        LOG.debug("stderr: %s", result.stderr.strip())
    return result


class OutcomeCategory(enum.Enum):
    PASSED = "passed"
    FAILED = "failed"
    ERROR = "error"
    EXPECTED_FAILURE = "expected failure"
    UNEXPECTED_PASS = "unexpected pass"
    FLAKY = "flaky"
    SKIPPED = "skipped"
    OTHER = "other"

    def display(self, count):
        if self == OutcomeCategory.PASSED:
            return f"{count} passed"
        if self == OutcomeCategory.FAILED:
            return f"{count} failed"
        if self == OutcomeCategory.ERROR:
            return f"{count} error{'' if count == 1 else 's'}"
        if self == OutcomeCategory.FLAKY:
            return f"{count} flaky"
        if self == OutcomeCategory.SKIPPED:
            return f"{count} skipped"
        return f"{count} {self.value}"


class JobRef(NamedTuple):
    """Identity of a workflow job, enough to derive its URLs."""

    id: int
    attempt: int


# ---------------------------------------------------------------------------
# GitHub API helpers
# ---------------------------------------------------------------------------


def gh_api(endpoint, method="GET", fields=None):
    cmd = ["gh", "api", endpoint]
    cmd += ["-H", "Accept: application/vnd.github+json"]
    cmd += ["-H", "X-GitHub-Api-Version: 2022-11-28"]
    if method != "GET":
        cmd += ["-X", method]
    if fields:
        for k, v in fields.items():
            cmd += ["-f", f"{k}={v}"]
    result = run_logged(cmd, check=True)
    if result.stdout.strip():
        return json.loads(result.stdout)
    return None


def gh_api_list(endpoint, key):
    """Collect paginated results from a list endpoint."""
    items = []
    page = 1
    while True:
        LOG.debug("listing %s (page %d)", endpoint, page)
        data = gh_api(f"{endpoint}?per_page=100&page={page}")
        items.extend(data[key])
        LOG.debug(
            "%s page %d returned %d item(s) (total %d)",
            endpoint,
            page,
            len(data[key]),
            len(items),
        )
        if len(data[key]) < 100:
            break
        page += 1
    return items


def gh_api_json(endpoint, method, payload):
    """Call the API with a JSON request body read from stdin.

    Used for large bodies (e.g. a full comment) that would overflow argv or
    need fragile escaping with the `-f`/`--field` form.
    """
    cmd = [
        "gh",
        "api",
        endpoint,
        "-H",
        "Accept: application/vnd.github+json",
        "-H",
        "X-GitHub-Api-Version: 2026-03-10",
        "-X",
        method,
        "--input",
        "-",
    ]
    result = run_logged(cmd, check=True, input_text=json.dumps(payload))
    if result.stdout.strip():
        return json.loads(result.stdout)
    return None


# ---------------------------------------------------------------------------
# Helpers mirroring the original inline JS
# ---------------------------------------------------------------------------


def status_emoji(outcome):
    return {
        "PASSED": "\u2705",
        "UNEXPECTED PASS": "\u2705\u2753",
        "FAILED": "\u274c",
        "ERROR": "\U0001f4a3",
        "SKIPPED": "\u23ed\ufe0f",
        "EXPECTED FAILURE": "\U0001f527",
        "FLAKY": "\u26a0\ufe0f",
    }.get(outcome.upper(), f"\u2753({outcome})")


def scenario_label(result, repo):
    name = result["name"]
    if result.get("is_new"):
        name = "*(New)* " + name
    outcome = result.get("outcome", "")
    gh_issue = result.get("gh_issue")
    if outcome in ("expected failure", "unexpected pass"):
        if gh_issue:
            name += (
                f" ([#{gh_issue}]"
                f"(https://github.com/{repo}/issues/{gh_issue}))"
            )
        else:
            name += " (missing GH issue!)"
    return name


def attempt_duration(result):
    """Wall-clock duration of a single attempt, or "" if unavailable.

    Uses start_time/end_time (present on every platform, unlike the
    recording-relative start_ms/end_ms) so slow tests can be spotted even
    where no video is recorded. On recording platforms this equals the clip
    window.
    """
    start = result.get("start_time")
    end = result.get("end_time")
    if start is None or end is None:
        return ""
    return format_duration(end - start)


def normalized_error_key(attempt):
    """Canonical merge key: first line of error, trimmed."""
    return (attempt.get("error") or "*(no output)*").split("\n")[0].strip()


def merge_failure_groups(attempts):
    """Order-preserving grouping of attempts by error key."""
    by_key = {}
    for a in attempts:
        k = normalized_error_key(a)
        by_key.setdefault(k, []).append(a)

    ordered_keys = []
    seen = set()
    for a in sorted(attempts, key=lambda x: x.get("start_time") or 0):
        k = normalized_error_key(a)
        if k not in seen:
            seen.add(k)
            ordered_keys.append(k)

    groups = []
    for k in ordered_keys:
        lst = sorted(by_key[k], key=lambda x: x.get("start_time") or 0)
        groups.append({"key": k, "attempts": lst, "latest": lst[-1]})
    return groups


def collapse_errors(attempts):
    pieces = []
    for a in attempts:
        outcome = a.get("outcome", "")
        if outcome not in ("failed", "error", "expected failure"):
            continue
        e = (a.get("error") or "").split("\n")[0]
        if not e:
            continue
        for raw in e.split(" / "):
            p = raw.strip().replace("|", "\\|")
            if p:
                pieces.append(p)
    counts = {}
    order = []
    for p in pieces:
        if p not in counts:
            order.append(p)
        counts[p] = counts.get(p, 0) + 1
    return " / ".join(
        f"{p} [x{counts[p]}]" if counts[p] > 1 else p for p in order
    )


def _attached_preview(attempts, allow_clips=True):
    """Return the preview image for the selected carrier.

    Clips are always emitted as `![Preview](relpath)` markers: `gh --attach`
    only rewrites markdown image references into the uploaded asset URL. A
    later pass (`promote_previews_to_video`) turns them into `<video>` tags,
    because a bare image marker does not render a consistent video player.
    """
    if not allow_clips:
        return ""
    for a in attempts:
        if a.get("_attach") and a.get("snippet_relpath"):
            return f"![Preview]({a['snippet_relpath']})"
    return ""


# Outcomes that still warrant an "Attempt N" label / error block. Passing
# attempts (and the pass-flavoured "unexpected pass"/"skipped") carry no error,
# so they must never be attributed to an error cell.
_ERROR_OUTCOMES = ("failed", "error", "expected failure", "flaky")


def _failure_blocks(attempts, log_url=None):
    """Label each merged error group with the attempts that produced it.

    Only failing attempts are considered: a retried-then-passed scenario shows
    the attempt(s) that errored, not the attempts that passed. Attempts sharing
    the same error are compacted into a single `**Attempt ...**` block.

    Unexpected failures (failed/error, not expected-failure/flaky) additionally
    carry the PID(s) of the mixxx-test process(es) the attempts ran against,
    in attempt order and matching the `mixxx-output.<pid>.log` artifact files,
    plus a link to the archive holding those logs.
    """
    failing = [a for a in attempts if a.get("outcome", "") in _ERROR_OUTCOMES]
    blocks = []
    for grp in merge_failure_groups(failing):
        nums = [a.get("_attempt_no", "?") for a in grp["attempts"]]
        block = f"**Attempt {', '.join(map(str, nums))}**"
        error = (grp["latest"].get("error") or "").split("\n")[0].strip()
        if error:
            block += (
                "<br><br><blockquote><p>"
                + error.replace("|", "\\|")
                + "</p></blockquote>"
            )
        if grp["latest"].get("outcome", "") in FAILURE_OUTCOMES:
            footer = ""
            pids = [
                pid
                for a in grp["attempts"]
                for pid in (a.get("mixxx_pids") or [])
            ]
            if pids:
                footer += "Mixxx process PID was " + ", ".join(
                    str(pid) for pid in pids
                )
            if log_url:
                footer += (" \u00b7 " if footer else "") + (
                    f"[Process logs archive]({log_url})"
                )
            if footer:
                block += f"<br><br><em>{footer}</em>"
        blocks.append(block)
    return blocks


def _error_cell(attempts, allow_clips=True, log_url=None):
    """Error blocks (labelled per merged group) + one whole-scenario clip.

    A single clip spanning the first attempt's start to the last attempt's end
    is appended once, regardless of whether the attempts share an error. The
    clip is looked up on the full attempt list because its carrier is the first
    attempt, which may itself have passed.
    """
    cell = "<hr> ".join(_failure_blocks(attempts, log_url))
    video = _attached_preview(attempts, allow_clips)
    if video:
        cell += ("<br>" if cell else "") + video
    return cell


def attempt_error_cell(attempts, allow_clips=True, log_url=None):
    """Failing scenario (T1): error blocks + whole-scenario video."""
    return _error_cell(attempts, allow_clips, log_url)


def eventual_success_cell(attempts, allow_clips=True, log_url=None):
    """Retried-then-passed scenario (T4): error history + whole-span video.

    Used when a scenario failed on earlier attempts but eventually passed
    (retries / flaky). Only the failing attempts are labelled; the clip spans
    the first attempt's start to the last (successful) attempt's end.
    """
    return _error_cell(attempts, allow_clips, log_url)


def scenario_clip_cell(attempts, allow_clips=True):
    """Clip-only error cell for a new, non-failed scenario."""
    recorded = [a for a in attempts if has_clip_window(a)]
    if not recorded:
        return ""
    return _attached_preview(attempts, allow_clips)


def format_duration(seconds):
    seconds = int(seconds)
    m, s = divmod(seconds, 60)
    h, m = divmod(m, 60)
    if h:
        return f"{h}:{m:02d}:{s:02d}"
    return f"{m}:{s:02d}"


def section_took(attempts):
    """Wall time from the earliest start to the latest end of the attempts.

    Returns None when any timestamp is missing so callers can omit the
    duration instead of printing a misleading value.
    """
    if not attempts:
        return None
    starts = [a.get("start_time") for a in attempts]
    ends = [a.get("end_time") for a in attempts]
    if any(s is None for s in starts) or any(e is None for e in ends):
        return None
    return max(ends) - min(starts)


def counts_suffix(counts, took=None):
    expected_total = (
        counts[OutcomeCategory.EXPECTED_FAILURE]
        + counts[OutcomeCategory.UNEXPECTED_PASS]
    )
    parts = [
        cat.display(counts[cat])
        for cat in (
            OutcomeCategory.PASSED,
            OutcomeCategory.FAILED,
            OutcomeCategory.ERROR,
            OutcomeCategory.FLAKY,
            OutcomeCategory.SKIPPED,
        )
        if counts[cat]
    ]
    if expected_total:
        parts.append(
            f"{expected_total} expected failure"
            f"{'s' if expected_total > 1 else ''}"
        )
    if took is not None:
        parts.append(f"took {format_duration(took)}")
    return f" ({', '.join(parts)})" if parts else ""


def section_mark(counts):
    if counts[OutcomeCategory.FAILED] or counts[OutcomeCategory.ERROR]:
        return ":x:"
    return ":white_check_mark:"


def summarize_counts(scenarios_by_name):
    """Tally the final outcome per scenario (last attempt by start time).

    `scenarios_by_name` must hold the scenarios of a single feature;
    scenario names are only unique within a feature, so the same name may
    legitimately occur in several features (e.g. when summing the feature
    counts of a whole platform).
    """
    counts = {cat: 0 for cat in OutcomeCategory}
    for name, attempts in scenarios_by_name.items():
        sorted_a = sorted(attempts, key=lambda a: a.get("start_time") or 0)
        last_a = sorted_a[-1]
        if not last_a:
            continue
        try:
            cat = OutcomeCategory(last_a.get("outcome", ""))
        except ValueError:
            cat = OutcomeCategory.OTHER
        counts[cat] += 1
    return counts, counts_suffix(counts)


# ---------------------------------------------------------------------------
# Data fetching
# ---------------------------------------------------------------------------


def fetch_video_urls(repo, run_id, server_url):
    """Map each recording stem to its artifact info (download URL and id).

    Returns {stem: {"url": str, "id": int}}; the URL is a browser link for
    the comment body, the id is used for lazy REST downloads.
    """
    LOG.info("fetching video artifacts for %s run %s", repo, run_id)
    artifacts = gh_api_list(
        f"/repos/{repo}/actions/runs/{run_id}/artifacts", "artifacts"
    )
    LOG.info("run %s exposes %d artifact(s)", run_id, len(artifacts))
    info = {}
    for a in artifacts:
        name = a.get("name", "")
        if name.endswith(".mkv"):
            basename = name[:-4]
            info[basename] = {
                "url": (
                    f"{server_url}/{repo}/actions/runs"
                    f"/{run_id}/artifacts/{a['id']}"
                ),
                "id": a.get("id"),
            }
            LOG.debug(
                "video artifact id=%s name=%s -> %s",
                a["id"],
                name,
                info[basename]["url"],
            )
        else:
            LOG.debug(
                "skipping non-video artifact id=%s name=%s", a.get("id"), name
            )
    LOG.info("mapped %d recording(s) to artifact URLs", len(info))
    return info


def fetch_job_ids(repo, run_id):
    """Map each testable platform name to the e2e job that ran it.

    The job name reported by the API is prefixed with the caller when the
    workflow is called as a reusable workflow (e.g. "build / Test e2e (macOS
    15 x64)"), so the prefix is optional in the pattern.
    """
    jobs = gh_api_list(f"/repos/{repo}/actions/runs/{run_id}/jobs", "jobs")
    LOG.info("run %s exposes %d job(s)", run_id, len(jobs))
    pattern = re.compile(r"(?:.* / )?Test e2e \((.+)\)")
    ids = {}
    for job in jobs:
        m = pattern.fullmatch(job.get("name", "") or "")
        if m:
            ids[m.group(1)] = JobRef(
                id=job["id"], attempt=job.get("run_attempt") or 1
            )
            LOG.debug(
                "job %r -> id=%s attempt=%s",
                job.get("name"),
                job["id"],
                job.get("run_attempt"),
            )
    LOG.info(
        "matched %d e2e job(s): %s",
        len(ids),
        ", ".join(sorted(ids)) or "(none)",
    )
    return ids


def job_links(job, repo, run_id, server_url):
    """Return the (job page, job summary) URLs for a job."""
    run_url = f"{server_url}/{repo}/actions/runs/{run_id}"
    return (
        f"{run_url}/job/{job.id}",
        f"{run_url}/attempts/{job.attempt}#summary-{job.id}",
    )


# ---------------------------------------------------------------------------
# Result parsing
# ---------------------------------------------------------------------------


def discover_local_videos(video_dir):
    """Walk video_dir recursively and return {stem: Path} for recordings."""
    videos = {}
    vdir = pathlib.Path(video_dir)
    if not vdir.is_dir():
        LOG.warning(
            "video dir %r does not exist; no recordings found", video_dir
        )
        return videos
    for f in vdir.rglob("*"):
        if f.is_file():
            videos[f.stem] = f
            LOG.debug("found recording %r -> %s", f.stem, f)
    LOG.info("discovered %d recording(s) under %s", len(videos), video_dir)
    return videos


def read_results(results_dir, video_urls, video_paths):
    """Parse JSON result files and augment with slug, video_url, video_path.

    For each JSON file, the file stem (basename without .json) is used to
    look up the corresponding recording in video_urls (remote artifact URL)
    and video_paths (local file path).
    """
    all_results = []
    rdir = pathlib.Path(results_dir)
    if not rdir.is_dir():
        LOG.warning("results dir %r does not exist", results_dir)
        return all_results

    for entry in sorted(rdir.iterdir()):
        if not entry.is_dir():
            continue
        dirname = entry.name
        slug = dirname
        if dirname.startswith("mixxx-ui-test-"):
            slug = dirname[len("mixxx-ui-test-") :]

        for jf in sorted(entry.iterdir()):
            if not jf.name.endswith(".json"):
                continue
            try:
                with open(jf, "r") as f:
                    results = json.load(f)
            except OSError as exc:
                LOG.warning("cannot read %s: %s", jf, exc)
                continue

            video_basename = jf.name.replace(".json", "")
            video_info = video_urls.get(video_basename)
            video_url = video_info.get("url") if video_info else None
            video_path = video_paths.get(video_basename)
            video_stem = video_basename if (video_info or video_path) else None
            LOG.debug(
                "parsed %s: %d result(s) slug=%s video_url=%s video_path=%s",
                jf,
                len(results),
                slug,
                "yes" if video_url else "no",
                video_path or "no",
            )

            for r in results:
                r["slug"] = slug
                r["video_url"] = video_url
                r["video_path"] = video_path
                r["video_stem"] = video_stem
                r["artifact_id"] = video_info.get("id") if video_info else None
                all_results.append(r)

    LOG.info(
        "read %d result(s) from %d dir(s) under %s",
        len(all_results),
        sum(1 for e in rdir.iterdir() if e.is_dir()),
        results_dir,
    )
    return all_results


def group_scenarios(all_results):
    """Group results by (slug, feature, scenario) preserving table order.

    Returns a list of (key, attempts) with attempts sorted by start time;
    scenario keys are ordered the same way as the comment table.
    """
    groups = {}
    for r in all_results:
        key = (r.get("slug"), r.get("feature"), r.get("name"))
        groups.setdefault(key, []).append(r)

    ordered = []
    for key, attempts in groups.items():
        attempts.sort(key=lambda a: a.get("start_time") or 0)
        ordered.append((key, attempts))
    ordered.sort(
        key=lambda item: (
            item[0][0] or "",
            item[0][1] or "",
            min(a.get("start_time") or 0 for a in item[1]),
        )
    )

    scenario_counters = {}
    for key, attempts in ordered:
        slug, feature = key[0], key[1]
        scenario_no = scenario_counters.get((slug, feature), 0) + 1
        scenario_counters[(slug, feature)] = scenario_no
        for i, a in enumerate(attempts, start=1):
            a["_attempt_no"] = i
            a["_scenario_no"] = scenario_no
    total_attempts = sum(len(a) for _k, a in ordered)
    LOG.info(
        "grouped %d result(s) into %d scenario(s)",
        total_attempts,
        len(ordered),
    )
    return ordered


def has_clip_window(result):
    """True when the attempt has a recording and a cuttable time window.

    A recording exists when a local file is known (`video_path`, NO_GITHUB
    mode or cache hit) or a remote artifact is known (`video_url`; the file
    is pulled lazily later).
    """
    return (
        result.get("video_stem") is not None
        and result.get("start_ms") is not None
        and result.get("end_ms") is not None
    )


def clip_window(attempts):
    """Time window spanning every clippable attempt in `attempts`.

    Returns (video_stem, start_ms, end_ms) covering the whole attempt
    sequence (earliest start to latest end), or None when no attempt has a
    recording window or the attempts do not share a single recording
    (a scenario's attempts always do, as one feature run writes one video).
    The recording is identified by its stem; its local file, if any, is
    resolved later from `video_paths`.
    """
    recorded = [a for a in attempts if has_clip_window(a)]
    if not recorded:
        return None
    stem = recorded[0]["video_stem"]
    if any(a["video_stem"] != stem for a in recorded):
        return None
    start = min(a["start_ms"] for a in recorded)
    end = max(a["end_ms"] for a in recorded)
    return (stem, start, end)


# ---------------------------------------------------------------------------
# New scenario detection
# ---------------------------------------------------------------------------


def normalize_scenario_name(name):
    """Drop behave's Scenario Outline example suffix.

    Outlines are expanded to "<name> -- @<row>.<example>" in results, while
    the feature file only carries "<name>", so both must compare equal.
    """
    return name.split(" -- @")[0].strip()


def _outline_regex(template):
    """Regex matching an expanded outline example name for `template`.

    Behave substitutes "<placeholder>" values into the example name, so the
    feature file's template is compared with placeholders as wildcards.
    """
    parts = re.split(r"<[^>]*>", template)
    pattern = r".*?".join(re.escape(p) for p in parts)
    return re.compile(rf"^{pattern}$")


def _parse_feature_scenarios(text):
    """Return (feature_name, [(name, is_outline), ...]) from Gherkin source."""
    feature = None
    scenarios = []
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("Feature:"):
            feature = stripped[len("Feature:") :].strip()
        else:
            match = re.match(r"^Scenario( Outline)?:(.*)$", stripped)
            if match:
                scenarios.append(
                    (match.group(2).strip(), match.group(1) is not None)
                )
    return feature, scenarios


def collect_scenarios_from_ref(ref):
    """Collect the scenarios defined at git ref `ref`.

    Returns {"exact": {(feature, name)}, "outline": {feature: [regex, ...]}}
    covering plain scenarios and Scenario Outlines (the latter matching the
    expanded example names). Returns an empty structure and warns when git
    cannot resolve the ref, so callers can skip highlighting instead of
    flagging every scenario as new.
    """
    base = {"exact": set(), "outline": {}}
    try:
        listing = run_logged(
            ["git", "ls-tree", "-r", "--name-only", ref, "--", FEATURES_DIR],
            check=True,
        )
    except (OSError, subprocess.CalledProcessError) as exc:
        LOG.warning("cannot list scenarios in %r: %s", ref, exc)
        return base

    feature_files = 0
    for path in listing.stdout.splitlines():
        path = path.strip()
        if not path.endswith(".feature"):
            continue
        try:
            blob = run_logged(["git", "show", f"{ref}:{path}"], check=True)
        except (OSError, subprocess.CalledProcessError) as exc:
            LOG.warning("cannot read %s at %r: %s", path, ref, exc)
            continue
        feature, scenarios = _parse_feature_scenarios(blob.stdout)
        if not feature:
            LOG.debug("no Feature: header in %s at %r", path, ref)
            continue
        feature_files += 1
        for name, is_outline in scenarios:
            name = normalize_scenario_name(name)
            base["exact"].add((feature, name))
            if is_outline:
                base["outline"].setdefault(feature, []).append(
                    _outline_regex(name)
                )
    LOG.info(
        "base %s: %d scenario(s) across %d feature file(s), " "%d outline(s)",
        ref,
        len(base["exact"]),
        feature_files,
        sum(len(v) for v in base["outline"].values()),
    )
    return base


def _is_known_scenario(base, feature, expanded_name):
    """True when `expanded_name` also exists at the base ref."""
    name = normalize_scenario_name(expanded_name)
    if (feature, name) in base["exact"]:
        return True
    return any(regex.match(name) for regex in base["outline"].get(feature, ()))


def mark_new_scenarios(all_results, base_ref):
    """Flag results whose scenario does not exist at `base_ref`."""
    if not base_ref:
        LOG.info("BASE_REF not set; skipping new-scenario detection")
        return
    base = collect_scenarios_from_ref(base_ref)
    if not base["exact"]:
        LOG.warning(
            "no scenarios found at %r; not flagging any as new", base_ref
        )
        return
    new_count = 0
    for result in all_results:
        result["is_new"] = not _is_known_scenario(
            base, result.get("feature"), result.get("name", "")
        )
        if result["is_new"]:
            new_count += 1
            LOG.debug(
                "new vs %s: %s / %s",
                base_ref,
                result.get("feature"),
                result.get("name"),
            )
    LOG.info(
        "flagged %d/%d result(s) as new against %s",
        new_count,
        len(all_results),
        base_ref,
    )


def plan_snippets(all_results, snippet_dir, max_attachments):
    """Decide which scenarios get an attached clip.

    Three-tier priority (failures first), one clip per scenario spanning
    the first to the last attempt:

    * T1 - failing scenarios (last outcome failed/error), guaranteed.
    * T3 - new, non-failed scenarios (single attempt or, when the last
      attempt did not pass, a whole-scenario span). New eventual-success
      scenarios are handled by T4.
    * T4 - eventual success: two or more attempts whose last attempt
      passed. Lowest priority, so it only gets the leftover budget.

    The old "one clip per distinct error group" (T2) is gone: a failing
    scenario now shows a single whole-scenario video.
    """
    ordered = group_scenarios(all_results)

    def assign_snippet(carrier, video_stem, start_ms, end_ms, attempts):
        if "snippet_relpath" in carrier:
            return
        scenario_no = carrier["_scenario_no"]
        first_no = attempts[0].get("_attempt_no", "?")
        last_no = attempts[-1].get("_attempt_no", "?")
        span = (
            f"a{first_no}" if first_no == last_no else f"a{first_no}-{last_no}"
        )
        fname = f"{video_stem}-s{scenario_no:02d}-{span}.mp4"
        carrier["_clip_video"] = video_stem
        carrier["_clip_start_ms"] = start_ms
        carrier["_clip_end_ms"] = end_ms
        carrier["snippet_relpath"] = str(pathlib.Path(snippet_dir) / fname)

    selected_ids = set()
    selected_list = []

    def pick_span(attempts):
        """Attach one whole-scenario clip carried by the first attempt."""
        if len(selected_list) >= max_attachments:
            return False
        window = clip_window(attempts)
        if window is None:
            return False
        carrier = attempts[0]
        aid = id(carrier)
        if aid in selected_ids:
            return False
        video, start_ms, end_ms = window
        assign_snippet(carrier, video, start_ms, end_ms, attempts)
        selected_ids.add(aid)
        selected_list.append(carrier)
        carrier["_attach"] = True
        return True

    # T1: guaranteed one per failing scenario (whole-scenario span).
    for _key, attempts in ordered:
        if attempts[-1].get("outcome", "") not in FAILURE_OUTCOMES:
            continue
        if len(selected_list) >= max_attachments:
            break
        pick_span(attempts)

    # T3: new, non-failed scenarios (excluding eventual-success -> T4).
    if len(selected_list) < max_attachments:
        for _key, attempts in ordered:
            is_new = attempts[0].get("is_new", False)
            last_outcome = attempts[-1].get("outcome", "")
            if not is_new or last_outcome in FAILURE_OUTCOMES:
                continue
            if len(attempts) >= 2 and last_outcome == "passed":
                continue
            pick_span(attempts)

    # T4: eventual success (multiple attempts, last passed), lowest.
    if len(selected_list) < max_attachments:
        for _key, attempts in ordered:
            if len(attempts) < 2:
                continue
            if attempts[-1].get("outcome", "") != "passed":
                continue
            pick_span(attempts)

    LOG.info(
        "plan_snippets: budget=%d, selected=%d (T1 failures, T3 new, "
        "T4 eventual-success)",
        max_attachments,
        len(selected_list),
    )
    return selected_list


def _build_ffmpeg_cmd(src, dst, start_ms, end_ms, ffmpeg_bin):
    """Build the ffmpeg argv to cut a [start_ms, end_ms] clip from src."""
    start = start_ms / 1000.0
    duration = (end_ms - start_ms) / 1000.0
    return [
        ffmpeg_bin,
        "-nostdin",
        "-hide_banner",
        "-loglevel",
        "error",
        "-y",
        "-ss",
        f"{start:.3f}",
        "-i",
        str(src),
        "-t",
        f"{duration:.3f}",
        "-c:v",
        "libx264",
        "-preset",
        "veryfast",
        "-crf",
        "26",
        "-pix_fmt",
        "yuv420p",
        "-an",
        "-movflags",
        "+faststart",
        dst,
    ]


def _ffmpeg_jobs_env():
    """Number of concurrent jobs: FFMPEG_JOBS or the logical CPU count."""
    raw = os.environ.get("FFMPEG_JOBS", "")
    fallback = max(1, (os.cpu_count() / 2) or 1)
    if not raw:
        return fallback
    try:
        n = int(raw)
    except ValueError:
        LOG.warning("invalid FFMPEG_JOBS %r; falling back to CPU count", raw)
        return fallback
    if n < 1:
        LOG.warning("FFMPEG_JOBS must be >= 1; falling back to CPU count")
        return fallback
    LOG.info("FFMPEG_JOBS=%d overridden by environment", n)
    return n


def _run_parallel_pool(jobs, workers):
    """Run child processes with up to `workers` running concurrently.

    Option A scheduler: launch (`subprocess.Popen`) up to `workers` child
    processes, poll with `poll()`, and launch a new job each time a running
    one exits. Completion is logged like `run_logged` does (exec line, exit
    code, duration), plus stderr on failure. Never raises: a job failure
    (nonzero exit, spawn error) is reported in the result, not thrown.

    `jobs` is a list of {"key": id, "cmd": argv}; the optional
    "stdout_path" routes the child's stdout into that file, otherwise it is
    discarded. Returns [(key, returncode, stderr)] in completion order, with
    returncode None on spawn failure. Callers do their own per-job result
    handling (e.g. artifact unzipping) after the pool has drained.
    """
    pending = list(jobs)
    running = []
    completed = []

    def fail(key, cmd, what):
        LOG.error("job %s: %s: %s", key, what, fmt_cmd(cmd))
        completed.append((key, None, what))

    def launch(job):
        cmd = job["cmd"]
        stdout_path = job.get("stdout_path")
        stdout = None
        LOG.info("job %s: exec: %s", job["key"], fmt_cmd(cmd))
        try:
            if stdout_path:
                stdout = open(stdout_path, "wb")
                running.append(
                    (
                        job,
                        subprocess.Popen(
                            cmd, stdout=stdout, stderr=subprocess.PIPE
                        ),
                        time.monotonic(),
                    )
                )
            else:
                running.append(
                    (
                        job,
                        subprocess.Popen(
                            cmd,
                            stdout=subprocess.DEVNULL,
                            stderr=subprocess.PIPE,
                        ),
                        time.monotonic(),
                    )
                )
        except OSError as exc:
            fail(job["key"], cmd, f"failed to spawn: {exc}")
        finally:
            if stdout is not None:
                stdout.close()

    while pending or running:
        while pending and len(running) < workers:
            launch(pending.pop(0))
        if not running:
            continue
        still_running = []
        for job, proc, started in running:
            rc = proc.poll()
            if rc is None:
                still_running.append((job, proc, started))
                continue
            key = job["key"]
            elapsed = time.monotonic() - started
            stderr = proc.communicate()[1].decode(errors="replace").strip()
            if rc == 0:
                LOG.debug(
                    "job %s: exit=0 after %.2fs (stderr=%dB)",
                    key,
                    elapsed,
                    len(stderr),
                )
            else:
                LOG.error(
                    "job %s: exit=%d after %.2fs: %s\nstderr: %s",
                    key,
                    rc,
                    elapsed,
                    fmt_cmd(job["cmd"]),
                    stderr,
                )
            completed.append((key, rc, stderr))
        running = still_running
        if running:
            time.sleep(0.05)
    return completed


def generate_snippets(selected, ffmpeg_bin, snippet_dir, video_paths):
    """Cut one .mp4 clip per selected scenario; return the paths to attach.

    Each selected carrier may define a clip range spanning several attempts
    (`_clip_video` / `_clip_start_ms` / `_clip_end_ms`); otherwise the
    carrier's own attempt window is used. `_clip_video` holds the recording
    stem, resolved against `video_paths` (the local cache, possibly filled
    lazily by download_snippet_videos). Carriers whose clip cannot be
    produced have `_attach` cleared, so the comment omits the video. Clips
    are cut with up to FFMPEG_JOBS ffmpeg processes running in parallel.
    """
    os.makedirs(snippet_dir, exist_ok=True)
    if shutil.which(ffmpeg_bin) is None:
        LOG.warning(
            "%s not found on PATH; falling back to video links", ffmpeg_bin
        )
        for a in selected:
            a["_attach"] = False
        return []

    jobs = []
    reused = set()
    for a in selected:
        dst = a["snippet_relpath"]
        if os.path.exists(dst):
            LOG.info(
                "clip already exists, reusing: %s (%d B)",
                dst,
                os.path.getsize(dst),
            )
            reused.add(dst)
            continue
        src = video_paths.get(a.get("_clip_video")) or a.get("video_path")
        start_ms = a.get("_clip_start_ms", a.get("start_ms"))
        end_ms = a.get("_clip_end_ms", a.get("end_ms"))
        if not src:
            LOG.warning(
                "no local recording for %s (stem=%s); skipping",
                dst,
                a.get("_clip_video"),
            )
            a["_attach"] = False
            continue
        duration = (end_ms - start_ms) / 1000.0
        if duration <= 0:
            LOG.warning(
                "invalid clip window for %s (start_ms=%s end_ms=%s); "
                "skipping",
                dst,
                start_ms,
                end_ms,
            )
            a["_attach"] = False
            continue
        cmd = _build_ffmpeg_cmd(src, dst, start_ms, end_ms, ffmpeg_bin)
        # TODO: adapt the encoder settings/bitrate so each clip stays under
        # GitHub's ~10 MB attachment limit; currently full attempts are cut
        # with a fixed CRF and no size cap.
        LOG.info(
            "cutting clip %s from %s (%.3fs @ %sms -> %sms)",
            dst,
            src,
            duration,
            start_ms,
            end_ms,
        )
        jobs.append({"carrier": a, "cmd": cmd, "dst": dst})

    attached = list(reused)
    if jobs:
        workers = min(_ffmpeg_jobs_env(), len(jobs))
        LOG.info(
            "cutting %d clip(s) with up to %d concurrent ffmpeg job(s)",
            len(jobs),
            workers,
        )
        pool_jobs = [{"key": j["dst"], "cmd": j["cmd"]} for j in jobs]
        failures_by_dst = {
            key: stderr
            for key, rc, stderr in _run_parallel_pool(pool_jobs, workers)
            if rc != 0
        }
        for job in jobs:
            a = job["carrier"]
            dst = job["dst"]
            if dst in failures_by_dst:
                LOG.error(
                    "ffmpeg failed for %s: %s", dst, failures_by_dst[dst]
                )
                a["_attach"] = False
                continue
            if not os.path.exists(dst):
                LOG.error("ffmpeg produced no output for %s; skipping", dst)
                a["_attach"] = False
                continue
            LOG.info("wrote %s (%d B)", dst, os.path.getsize(dst))
            attached.append(dst)

    # Restore `selected` order for a stable attachment list.
    order = [a["snippet_relpath"] for a in selected]
    attached = sorted(
        attached, key=lambda p: order.index(p) if p in order else len(order)
    )
    LOG.info(
        "generated %d/%d clip(s) into %s",
        len(attached),
        len(selected),
        snippet_dir,
    )
    return attached


# ---------------------------------------------------------------------------
# Lazy recording downloads
# ---------------------------------------------------------------------------


def _store_artifact_payload(tmp_path, dst_path):
    """Persist a downloaded artifact as `dst_path`, sniffing its payload.

    The HTTP body is either the raw .mkv (skipArchive uploads) or a zip
    archive holding it (archived uploads): `zipfile.is_zipfile` tells them
    apart, so a change in encoding stays transparent. Raises *nothing*: it
    logs a warning and returns False on any unexpected payload.

    Zip members are restricted to a plain single file to defeat zip-slip
    paths and partial-archive surprises.
    """
    try:
        # The artifact *metadata* JSON (served by the wrong endpoint, or on
        # auth/permission hiccups) is the most likely non-video payload.
        with open(tmp_path, "rb") as f:
            head = f.read(1)
        if head == b"{":
            LOG.warning(
                "artifact payload is JSON (metadata, not recording); "
                "dropping recording"
            )
            return False
        if zipfile.is_zipfile(tmp_path):
            with zipfile.ZipFile(tmp_path) as zf:
                members = [i for i in zf.infolist() if not i.is_dir()]
                if len(members) != 1:
                    LOG.warning(
                        "unexpected %d file(s) in artifact archive; "
                        "dropping recording",
                        len(members),
                    )
                    return False
                name = members[0].filename.replace("\\", "/")
                if pathlib.PurePosixPath(name).name != name:
                    LOG.warning(
                        "unsafe archive member %r; dropping recording", name
                    )
                    return False
                with zf.open(members[0]) as src, open(dst_path, "wb") as out:
                    shutil.copyfileobj(src, out, 1 << 20)
        else:
            if os.path.getsize(tmp_path) <= 0:
                LOG.warning("empty artifact payload; dropping recording")
                return False
            shutil.move(os.fspath(tmp_path), os.fspath(dst_path))
        return True
    except (OSError, zipfile.BadZipFile) as exc:
        LOG.warning("cannot persist recording: %s", exc)
        return False


def download_snippet_videos(
    repo, selected, all_results, video_info, video_paths, video_dir
):
    """Lazily download the recordings referenced by the selected carriers.

    `gh run download` cannot handle non-archived (skipArchive) artifacts
    (cli/cli#13012), so recordings are fetched over the artifact REST API in
    parallel with up to FFMPEG_JOBS workers. Recording stem values already
    present in `video_paths` (or as a non-empty <stem>.mkv in video_dir,
    e.g. from a retried run) are reused instead of re-downloaded. A
    recording that cannot be had only drops the video from its scenarios
    (`_attach = False`); the comment is still posted.

    On success, `video_paths[stem]` points at the local recording and every
    result carrying that recording (matched `video_url`) gets its
    `video_path` filled in, so generate_snippets can cut clips from it.
    """
    os.makedirs(video_dir, exist_ok=True)

    def carriers_for(stem):
        return [a for a in selected if a.get("_clip_video") == stem]

    def drop_attachment(stem):
        # Recording unavailable: degrade gracefully to artifact links.
        for a in carriers_for(stem):
            a["_attach"] = False

    # Cache hits (retried runs or pre-seeded VIDEO_DIR) need no download.
    missing = []
    for stem in sorted(
        {a["_clip_video"] for a in selected if a["_clip_video"]}
    ):
        if stem in video_paths:
            continue
        cached = os.path.join(video_dir, f"{stem}.mkv")
        if os.path.exists(cached) and os.path.getsize(cached) > 0:
            LOG.info("recording %s already cached in %s", stem, video_dir)
            video_paths[stem] = cached
            continue
        missing.append(stem)

    downloads = []
    for stem in missing:
        info = video_info.get(stem)
        if not info or not info.get("id"):
            LOG.warning(
                "no artifact for recording %s; dropping its clips", stem
            )
            drop_attachment(stem)
            continue
        downloads.append(stem)

    if downloads:
        workers = min(_ffmpeg_jobs_env(), len(downloads))
        LOG.info(
            "downloading %d recording(s) with up to %d concurrent job(s)",
            len(downloads),
            workers,
        )
        jobs = []
        for stem in downloads:
            fd, tmp_path = tempfile.mkstemp(
                prefix=f".{stem}.", suffix=".part", dir=video_dir
            )
            os.close(fd)
            artifact_id = video_info[stem]["id"]
            jobs.append(
                {
                    "key": stem,
                    "cmd": [
                        "gh",
                        "api",
                        # The plain /artifacts/<id> endpoint returns
                        # *metadata* JSON; only the /zip route serves the
                        # payload (raw bytes for skipArchive artifacts).
                        f"/repos/{repo}/actions/artifacts/{artifact_id}/zip",
                    ],
                    "stdout_path": tmp_path,
                }
            )
        tmp_by_stem = {j["key"]: j["stdout_path"] for j in jobs}
        for stem, rc, _stderr in _run_parallel_pool(jobs, workers):
            tmp_path = tmp_by_stem[stem]
            dst_path = os.path.join(video_dir, f"{stem}.mkv")
            try:
                ok = (
                    rc == 0
                    and os.path.exists(tmp_path)
                    and _store_artifact_payload(tmp_path, dst_path)
                )
            finally:
                if os.path.exists(tmp_path):
                    os.unlink(tmp_path)
            if not ok:
                LOG.error(
                    "recording %s could not be downloaded; dropping its clips",
                    stem,
                )
                drop_attachment(stem)
                continue
            video_paths[stem] = dst_path
            LOG.info("wrote %s (%d B)", dst_path, os.path.getsize(dst_path))

    # Propagate local paths to every result carrying these recordings, so
    # generate_snippets can resolve the clip source per attempt.
    for stem, path in video_paths.items():
        url = (video_info.get(stem) or {}).get("url")
        if not url:
            continue
        for r in all_results:
            if r.get("video_url") == url and r.get("video_path") is None:
                r["video_path"] = path

    downloaded = sum(1 for s in downloads if s in video_paths)
    LOG.info(
        "recording availability: %d download(s) this run, %d cached "
        "or reused, %d failed for %d needed",
        downloaded,
        len(video_paths) - downloaded,
        len(downloads) - downloaded,
        len(video_paths) + len(downloads) - downloaded,
    )
    return missing


# ---------------------------------------------------------------------------
# Comment body generation
# ---------------------------------------------------------------------------


def build_comment_body(
    all_results, job_ids, repo, run_id, server_url, allow_clips=True
):
    if not all_results:
        LOG.warning("no test results found; emitting placeholder comment")
        return f"{TITLE_MARKER}\n# E2E Test\n\n**No test report found**\n"

    # Group by slug -> feature -> scenario name
    by_slug = {}
    for r in all_results:
        slug = r.get("slug", "unknown")
        by_slug.setdefault(slug, {}).setdefault(
            r.get("feature", "unknown"), {}
        ).setdefault(r.get("name", "unknown"), []).append(r)

    # Totals across all results (scenario names are only unique per feature)
    unique_scenarios = {(r.get("feature"), r.get("name")) for r in all_results}
    unique_slugs = {r.get("slug") for r in all_results if r.get("slug")}

    body_lines = [
        TITLE_MARKER,
        "# E2E Test",
        "",
        (
            f"**{len(unique_scenarios)} scenarios"
            f" across {len(unique_slugs)} platform"
            f"{'s' if len(unique_slugs) > 1 else ''}**"
        ),
        "",
    ]

    for slug in sorted(by_slug.keys()):
        by_feature = by_slug[slug]
        base_slug = re.sub(r"-e2e$", "", slug)
        slug_name = SLUG_NAMES.get(base_slug, slug)
        job = job_ids.get(slug_name)
        job_url = summary_url = None
        if job is not None:
            job_url, summary_url = job_links(job, repo, run_id, server_url)

        # Per-platform stats (sum of the feature stats, last attempt per
        # scenario) plus total wall time across the platform's scenarios
        plat_counts = {cat: 0 for cat in OutcomeCategory}
        for scenarios_by_name in by_feature.values():
            counts, _ = summarize_counts(scenarios_by_name)
            for cat, n in counts.items():
                plat_counts[cat] += n
        plat_took = section_took(
            [
                a
                for feat_dict in by_feature.values()
                for att_list in feat_dict.values()
                for a in att_list
            ]
        )
        stat_suffix = counts_suffix(plat_counts, plat_took)
        title_text = f"{section_mark(plat_counts)} {slug_name}{stat_suffix}"

        feature_lines = [
            "<details>",
            f"<summary><strong>{title_text}</strong></summary>",
            "",
        ]

        has_duration = any(
            r.get("start_time") is not None and r.get("end_time") is not None
            for feat_dict in by_feature.values()
            for att_list in feat_dict.values()
            for r in att_list
        )

        for feature in sorted(by_feature.keys()):
            scenarios_by_name = by_feature[feature]
            feat_took = section_took(
                [
                    a
                    for att_list in scenarios_by_name.values()
                    for a in att_list
                ]
            )
            feat_counts = summarize_counts(scenarios_by_name)[0]
            feat_suffix = counts_suffix(feat_counts, feat_took)
            if job_url:
                feat_summary = (
                    f"<strong>├─ {section_mark(feat_counts)}"
                    f'<a href="{job_url}">{feature}</a>{feat_suffix}</strong>'
                )
            else:
                feat_summary = (
                    f"<strong>├─ {section_mark(feat_counts)}"
                    f"{feature}{feat_suffix}</strong>"
                )
            feature_lines.append("<details>")
            feature_lines.append(f"<summary>{feat_summary}</summary>")
            feature_lines.append("")

            cols = ["scenario", "status", "error"]
            if has_duration:
                cols.insert(2, "duration")

            def _sort_key(name):
                attempts = scenarios_by_name[name]
                is_new = any(a.get("is_new") for a in attempts)
                first_time = min(a.get("start_time") or 0 for a in attempts)
                return (0 if is_new else 1, first_time)

            table = []
            for name in sorted(scenarios_by_name.keys(), key=_sort_key):
                attempts = sorted(
                    scenarios_by_name[name],
                    key=lambda a: a.get("start_time") or 0,
                )
                last_outcome = attempts[-1].get("outcome", "")
                is_new = any(a.get("is_new") for a in attempts)
                if last_outcome in FAILURE_OUTCOMES:
                    error_cell = attempt_error_cell(
                        attempts, allow_clips, summary_url
                    )
                elif len(attempts) >= 2:
                    error_cell = eventual_success_cell(
                        attempts, allow_clips, summary_url
                    )
                elif is_new:
                    error_cell = scenario_clip_cell(attempts, allow_clips)
                else:
                    error_cell = collapse_errors(attempts)
                values = {
                    "scenario": scenario_label(attempts[0], repo),
                    "status": " / ".join(
                        status_emoji(a.get("outcome", "")) for a in attempts
                    ),
                    "error": error_cell,
                }
                if has_duration:
                    values["duration"] = " / ".join(
                        attempt_duration(a) for a in attempts
                    )
                table.append(values)

            feature_lines.append(
                "| " + " | ".join(c.title() for c in cols) + " |"
            )
            feature_lines.append("|" + "---|" * len(cols))
            feature_lines.extend(
                [
                    "| " + " | ".join(row[c] for c in cols) + " |"
                    for row in table
                ]
            )

            feature_lines.append("")

            # Video link (from the latest attempt)
            all_attempts = [
                a for attempts in scenarios_by_name.values() for a in attempts
            ]
            if all_attempts:
                latest = max(
                    all_attempts, key=lambda a: a.get("start_time") or 0
                )
                video_url = latest.get("video_url")
                parts = []
                if summary_url:
                    parts.append(f"[Job summary]({summary_url})")
                if job_url:
                    parts.append(f"[Job logs]({job_url})")
                if video_url:
                    parts.append(f"[{feature} video]({video_url})")
                else:
                    parts.append("*No video available*")
                feature_lines.append(" \u00b7 ".join(parts))
                feature_lines.append("")

            feature_lines.append("</details>")
            feature_lines.append("")

        feature_lines.append("</details>")
        feature_lines.append("")
        body_lines.extend(feature_lines)

    body = "\n".join(body_lines)
    LOG.info(
        "built comment body: %d char(s), %d platform(s), %d unique "
        "scenario(s), %d inline clip(s)",
        len(body),
        len(unique_slugs),
        len(unique_scenarios),
        body.count("![Preview]"),
    )
    return body


# `gh --attach` rewrites markdown references that name an attached file into
# the uploaded asset URL. A `.mp4` is a "video" asset, and gh only lets a video
# render as a player when the bare URL is the whole content of a paragraph;
# inside a table cell (our inline cells) it degrades the embed to a link,
# dropping the leading `!`, so the posted body holds `[Preview](<url>)`. A bare
# image/link marker does not render a video player, so after gh has performed
# the local-file -> asset-URL substitution we re-edit the comment, replacing
# each marker with an inline <video> element. The `!` is optional so both the
# degraded link and the (paragraph) embed form are handled.
PREVIEW_MARKER_RE = re.compile(r"!?\[Preview\]\((https?://[^)\s]+)\)")
COMMENT_URL_RE = re.compile(r"#issuecomment-(\d+)")


def promote_previews_to_video(body):
    """Rewrite `[Preview](<http-url>)` markers into `<video>` tags.

    Only absolute http(s) URLs are converted, so markers gh could not upload
    (left as local relative paths) are preserved rather than turned into
    broken players.
    """
    return PREVIEW_MARKER_RE.sub(r'<video src="\1" controls></video>', body)


def comment_id_from_url(url):
    """Extract the numeric issue-comment id from a comment URL."""
    match = COMMENT_URL_RE.search(url or "")
    return int(match.group(1)) if match else None


def promote_comment_videos(repo, comment_url):
    """Second pass: convert posted preview markers into inline videos.

    Must run on the body GitHub already returned (after gh replaced the local
    paths with uploaded asset URLs); using the local body here would lose that
    substitution. Failures are logged but not fatal: the comment is already
    posted, only the player rendering degrades.
    """
    comment_id = comment_id_from_url(comment_url)
    if comment_id is None:
        LOG.warning(
            "could not parse comment id from gh output %r; "
            "skipping video promotion",
            comment_url,
        )
        return
    try:
        data = gh_api(f"/repos/{repo}/issues/comments/{comment_id}")
        body = (data or {}).get("body") or ""
        if "[Preview](" not in body:
            LOG.info(
                "comment %d has no preview markers to promote", comment_id
            )
            return
        promoted = promote_previews_to_video(body)
        if promoted == body:
            LOG.info(
                "comment %d preview markers are not uploaded URLs; "
                "nothing to promote",
                comment_id,
            )
            return
        repo_id = (gh_api(f"/repos/{repo}") or {}).get("id")
        if not repo_id:
            LOG.error(
                "unable to resolve repo ID for comment %s; "
                "comment left with preview markers",
                comment_id,
            )
            return
        gh_api_json(
            f"/repositories/{repo_id}/issues/comments/{comment_id}",
            "PATCH",
            {"body": promoted},
        )
        LOG.info(
            "promoted %d preview marker(s) to <video> in comment %d",
            promoted.count("<video "),
            comment_id,
        )
    except subprocess.CalledProcessError as exc:
        LOG.error(
            "video promotion failed for comment %s (exit=%s): %s; "
            "comment left with preview markers",
            comment_id,
            exc.returncode,
            (exc.stderr or "").strip(),
        )


def gh_comment(repo, pr_number, body, attach_paths):
    """Create or update the E2E comment via the `gh` CLI.

    `--edit-last` updates the bot's most recent comment (falling back with
    `--create-if-none` when there is none). Attachments in `attach_paths`
    are referenced by the same relative path in the body (as `![Preview]`
    markers), which gh rewrites to the uploaded asset URLs. A second pass
    then swaps those markers for inline `<video>` players.
    """
    fd, body_file = tempfile.mkstemp(suffix=".md", text=True)
    try:
        with os.fdopen(fd, "w") as f:
            f.write(body)
        LOG.info(
            "updating comment on %s#%s with %d attachment(s) "
            "(body %d char(s))",
            repo,
            pr_number,
            len(attach_paths),
            len(body),
        )
        cmd = [
            "gh",
            "pr",
            "comment",
            str(pr_number),
            "--repo",
            repo,
            "--edit-last",
            "--create-if-none",
            "--body-file",
            body_file,
        ]
        for path in attach_paths:
            cmd += ["--attach", path]
        result = run_logged(cmd)
        if result.returncode != 0:
            LOG.error(
                "gh comment failed (exit=%d): %s",
                result.returncode,
                (result.stderr or "").strip(),
            )
        else:
            LOG.info("gh comment updated successfully")
            if attach_paths:
                promote_comment_videos(repo, result.stdout.strip())
        return result
    finally:
        os.unlink(body_file)


def main():
    repo = os.environ.get("GITHUB_REPOSITORY", "")
    run_id = os.environ.get("GITHUB_RUN_ID", "")
    server_url = os.environ.get("GITHUB_SERVER_URL", "https://github.com")
    pr_number = os.environ.get("PR_NUMBER", "")
    results_dir = os.environ.get("RESULTS_DIR", "results")
    video_dir = os.environ.get("VIDEO_DIR", results_dir)
    snippet_dir = os.environ.get("SNIPPET_DIR", "snippets")
    max_attachments = max(
        0, int(os.environ.get("SNIPPET_MAX_ATTACHMENTS", "40"))
    )
    ffmpeg_bin = os.environ.get("FFMPEG_BIN", "ffmpeg")
    base_ref = os.environ.get("BASE_REF", "")
    no_github = os.environ.get("NO_GITHUB", "") == "1"

    LOG.info("mixxx e2e comment generator starting")
    LOG.info(
        "config: repo=%r run_id=%r server_url=%r pr_number=%r",
        repo,
        run_id,
        server_url,
        pr_number,
    )
    LOG.info(
        "config: results_dir=%r video_dir=%r snippet_dir=%r",
        results_dir,
        video_dir,
        snippet_dir,
    )
    LOG.info(
        "config: max_attachments=%d ffmpeg_bin=%r base_ref=%r no_github=%s",
        max_attachments,
        ffmpeg_bin,
        base_ref,
        no_github,
    )
    token = os.environ.get("GH_TOKEN", "")
    LOG.info(
        "token: %s",
        (
            f"set ({len(token)} char(s), prefix {token[:4]!r})"
            if token
            else "not set"
        ),
    )
    LOG.info("cwd=%s", os.getcwd())

    # Build video maps (from API or local files)
    if no_github:
        LOG.info("NO_GITHUB=1: using local file:// URLs for recordings")
        video_paths = discover_local_videos(video_dir)
        video_urls = {
            stem: {"url": p.resolve().as_uri(), "id": None}
            for stem, p in video_paths.items()
        }
        job_ids = {}
    else:
        video_paths = {}
        video_urls = fetch_video_urls(repo, run_id, server_url)
        job_ids = fetch_job_ids(repo, run_id)

    all_results = read_results(results_dir, video_urls, video_paths)
    mark_new_scenarios(all_results, base_ref)

    # Pick the clips to attach, pull the recordings they need (lazily), then
    # cut the clips and render the body.
    selected = plan_snippets(all_results, snippet_dir, max_attachments)
    if not no_github:
        download_snippet_videos(
            repo, selected, all_results, video_urls, video_paths, video_dir
        )
    attached = generate_snippets(
        selected, ffmpeg_bin, snippet_dir, video_paths
    )
    body = build_comment_body(
        all_results, job_ids, repo, run_id, server_url, allow_clips=True
    )

    if no_github:
        LOG.info("NO_GITHUB=1: printing comment body to stdout")
        print(body)
        return

    if not pr_number:
        LOG.warning("PR_NUMBER not set; skipping comment update")
        return

    result = gh_comment(repo, pr_number, body, attached)
    if result.returncode == 0:
        return

    # Attachments may be rejected (e.g. the ghs_ Actions token is not
    # accepted by `gh --attach`); retry with artifact links only.
    LOG.warning(
        "gh comment with attachments failed: %s",
        (result.stderr or "").strip(),
    )
    if not attached:
        raise SystemExit(result.returncode)
    LOG.info("retrying without attachments (artifact links only)")
    body = build_comment_body(
        all_results, job_ids, repo, run_id, server_url, allow_clips=False
    )
    retry = gh_comment(repo, pr_number, body, [])
    if retry.returncode != 0:
        LOG.error("retry without attachments failed: %s", retry.stderr)
        raise SystemExit(retry.returncode)


if __name__ == "__main__":
    main()
