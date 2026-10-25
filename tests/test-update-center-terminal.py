#!/usr/bin/python3
"""Durable Update Center terminal lifecycle and fixed provider adapters."""
import contextlib
import io
import json
import os
import runpy
import signal
import time
import subprocess
import sys
import tempfile
import termios
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
CENTER = ROOT / "scripts/dwm-update-center"
RUNNER = ROOT / "scripts/dwm-update-center-terminal"


class Environment(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir=os.environ.get("DWM_TEST_WORKSPACE") or None)
        self.addCleanup(self.temp.cleanup)
        self.environment = patch.dict(os.environ, {
            "XDG_STATE_HOME": str(Path(self.temp.name) / "state"),
            "XDG_CACHE_HOME": str(Path(self.temp.name) / "cache"),
        })
        self.environment.start()
        self.addCleanup(self.environment.stop)


class ReservationTests(Environment):
    def setUp(self):
        super().setUp()
        self.api = runpy.run_path(str(CENTER))

    def test_launch_is_fixed_argv_and_one_active_operation(self):
        calls = []
        class Child:
            pid = 321
        def launch(argv, **options):
            calls.append((argv, options))
            return Child()
        with patch.dict(self.api["launch_operation"].__globals__, subprocess_popen=launch,
                        validate_provider_action=lambda provider, action: None,
                        process_identity=lambda pid: "321:99"):
            first = self.api["launch_operation"]("flatpak", "update", terminal="/usr/bin/dwm-terminal",
                                                  runner="/usr/bin/dwm-update-center-terminal", now=10)
            self.assertRegex(first["operation"], r"^op-[0-9a-f]{32}$")
            self.assertEqual(calls[0][0], ["/usr/bin/dwm-terminal", "--update-center", "/usr/bin/dwm-update-center-terminal",
                                          first["operation"], "flatpak", "update"])
            self.assertFalse(calls[0][1].get("shell", False))
            with self.assertRaisesRegex(BlockingIOError, "active"):
                self.api["launch_operation"]("mise", "update", terminal="/usr/bin/dwm-terminal",
                                              runner="/usr/bin/dwm-update-center-terminal")

    def test_cli_launch_system_is_the_open_system_update_entry_point(self):
        calls = []

        class Child:
            pid = 654

        def launch(argv, **options):
            calls.append((argv, options))
            return Child()

        globals_ = self.api["main"].__globals__
        with patch.dict(globals_, require_arch=lambda: None,
                        validate_provider_action=lambda provider, action: calls.append((provider, action)),
                        subprocess_popen=launch, process_identity=lambda pid: "654:1"), \
                patch("sys.stdout", new_callable=io.StringIO) as output:
            self.assertEqual(self.api["main"](["launch", "system"]), 0)
        operation = self.api["read_operation"]()
        self.assertEqual(calls[0], ("system", "update"))
        argv = calls[1][0]
        self.assertEqual(argv[1:3], ["--update-center", str(RUNNER)])
        self.assertEqual(Path(argv[0]).name, "dwm-terminal")
        self.assertEqual(argv[3:], [operation["operation"], "system", "update"])
        self.assertTrue(calls[1][1]["start_new_session"])
        self.assertEqual((operation["provider"], operation["phase"], operation["terminal_pid"]),
                         ("system", "launched", 654))
        self.assertIn("\tsystem\tupdate\tlaunched\tpending", output.getvalue())
        with patch("sys.stderr", new_callable=io.StringIO):
            self.assertEqual(self.api["main"](["launch", "fedora"]), 2)

    def test_provider_and_action_injection_are_rejected_before_launch(self):
        with patch.dict(self.api["launch_operation"].__globals__, subprocess_popen=lambda *a, **k: self.fail("spawned"),
                        validate_provider_action=lambda provider, action: (_ for _ in ()).throw(ValueError("invalid"))):
            for provider in ("fedora;sh", "../mise", "unknown"):
                with self.subTest(provider=provider), self.assertRaises(ValueError):
                    self.api["launch_operation"](provider, "update")
            with self.assertRaises(ValueError):
                self.api["launch_operation"]("system", "update;sh")

    def test_malformed_durable_owner_fails_closed_without_replacement(self):
        path = self.api["operation_path"]()
        path.parent.mkdir(parents=True)
        path.write_text("{broken")
        before = path.read_bytes()
        with self.assertRaisesRegex(ValueError, "unsafe or malformed"):
            self.api["reserve_operation"]("system", "update")
        self.assertEqual(path.read_bytes(), before)

    def test_terminal_closed_never_claims_success_and_ambiguity_is_retained(self):
        op = self.api["reserve_operation"]("mise", "update", now=10)
        self.api["record_terminal"](op["operation"], 123, "123:7", now=11)
        with patch.dict(self.api["terminal_closed"].__globals__, process_identity=lambda pid: "123:8",
                        rescan_provider=lambda provider: None):
            result = self.api["terminal_closed"](op["operation"], now=12)
        self.assertEqual((result["phase"], result["outcome"]), ("interrupted", "unknown"))
        self.assertEqual(self.api["active_operation"]()["operation"], op["operation"])
        with patch.dict(self.api["terminal_closed"].__globals__, process_identity=lambda pid: None,
                        rescan_provider=lambda provider: None):
            repeated = self.api["terminal_closed"](op["operation"], now=13)
        self.assertEqual((repeated["phase"], repeated["outcome"]), ("interrupted", "unknown"))

    def test_terminal_closed_does_not_rescan_when_terminal_is_alive_and_phase_unchanged(self):
        op = self.api["reserve_operation"]("mise", "update", now=10)
        self.api["record_terminal"](op["operation"], 123, "123:7", now=11)
        rescanned = []
        with patch.dict(self.api["terminal_closed"].__globals__,
                        process_identity=lambda pid: "123:7",
                        rescan_provider=lambda provider: rescanned.append(provider)):
            result = self.api["terminal_closed"](op["operation"], now=12)
        self.assertEqual(rescanned, [])
        self.assertEqual(result["phase"], "launched")

    def test_matching_interrupted_owner_can_reserve_recovery_but_other_provider_cannot(self):
        previous = self.api["reserve_operation"]("flatpak", "update", now=10)
        self.api["update_operation"](previous["operation"], phase="interrupted", outcome="unknown")
        with self.assertRaisesRegex(ValueError, "no matching recoverable"):
            self.api["reserve_operation"]("mise", "recover", now=11)
        recovery = self.api["reserve_operation"]("flatpak", "recover", now=12)
        self.assertEqual((recovery["provider"], recovery["action"], recovery["phase"]),
                         ("flatpak", "recover", "reserved"))
        self.assertEqual(recovery["recovery_of"], previous["operation"])

    def test_recovery_waits_until_interrupted_terminal_is_really_gone(self):
        previous = self.api["reserve_operation"]("mise", "update", now=10)
        self.api["record_terminal"](previous["operation"], 555, "555:9", now=11)
        self.api["update_operation"](previous["operation"], phase="interrupted", outcome="unknown")
        globals_ = self.api["reserve_operation"].__globals__
        with patch.dict(globals_, process_identity=lambda pid: "555:9"), self.assertRaises(BlockingIOError):
            self.api["reserve_operation"]("mise", "recover", now=12)
        with patch.dict(globals_, process_identity=lambda pid: None):
            recovery = self.api["reserve_operation"]("mise", "recover", now=13)
        self.assertEqual(recovery["recovery_of"], previous["operation"])

    def test_close_preserves_flatpak_partial_completion_recovery_phase(self):
        operation = self.api["reserve_operation"]("flatpak", "update", now=10)
        self.api["update_operation"](operation["operation"], phase="system-complete/user-failed",
                                     provider_phase="flatpak-user", outcome="failed")
        with patch.dict(self.api["terminal_closed"].__globals__, process_identity=lambda pid: None,
                        rescan_provider=lambda provider: None):
            closed = self.api["terminal_closed"](operation["operation"], now=11)
        self.assertEqual((closed["phase"], closed["provider_phase"]),
                         ("system-complete/user-failed", "flatpak-user"))

    def test_repeated_flatpak_recovery_preserves_completed_scope(self):
        runner = runpy.run_path(str(RUNNER))
        for phase in ("reserved", "recovering", "flatpak-user", "flatpak-user-complete"):
            with self.subTest(phase=phase):
                previous = self.api["reserve_operation"]("flatpak", "update")
                self.api["update_operation"](previous["operation"], phase="system-complete/user-failed",
                    provider_phase="flatpak-user", outcome="failed")
                recovery = self.api["reserve_operation"]("flatpak", "recover")
                # Include receipts produced before recovery preserved checkpoints.
                self.api["update_operation"](recovery["operation"], phase="interrupted",
                    outcome="unknown", provider_phase=phase)
                retry = self.api["reserve_operation"]("flatpak", "recover")
                expected = "flatpak-user-complete" if phase == "flatpak-user-complete" else "flatpak-user"
                self.assertEqual(retry["provider_phase"], expected)
                self.assertEqual(retry["recovery_provider_phase"], expected)
                with contextlib.redirect_stdout(io.StringIO()):
                    runner["checkpoint"](retry["operation"], "recovering", "Rechecking scopes")
                self.assertEqual(self.api["read_operation"]()["provider_phase"], expected)
                self.api["update_operation"](retry["operation"], phase="closed", outcome="unknown")

    def test_child_completion_cannot_be_regressed_to_launched_by_parent(self):
        class Child:
            pid = 456
        globals_ = self.api["launch_operation"].__globals__
        def launch(argv, **options):
            active = self.api["active_operation"]()
            self.api["update_operation"](active["operation"], phase="completed", outcome="succeeded",
                                         detail="Child finished")
            return Child()
        with patch.dict(globals_, subprocess_popen=launch, process_identity=lambda pid: "456:1",
                        validate_provider_action=lambda provider, action: None):
            value = self.api["launch_operation"]("system", now=10)
        self.assertEqual((value["phase"], value["outcome"], value["detail"]),
                         ("completed", "succeeded", "Child finished"))
        self.assertEqual(value["terminal_identity"], "456:1")

    def test_child_completion_wins_even_when_parent_cannot_observe_process(self):
        class Child:
            pid = 457
        def launch(argv, **options):
            active = self.api["active_operation"]()
            self.api["update_operation"](active["operation"], phase="completed", outcome="succeeded",
                                         detail="Child finished before identity capture")
            return Child()
        globals_ = self.api["launch_operation"].__globals__
        with patch.dict(globals_, subprocess_popen=launch, process_identity=lambda pid: None,
                        validate_provider_action=lambda provider, action: None):
            value = self.api["launch_operation"]("system", now=10)
        self.assertEqual((value["phase"], value["outcome"]), ("completed", "succeeded"))
        self.assertEqual((value["terminal_pid"], value["terminal_identity"]), (457, ""))
        with patch.dict(globals_, process_identity=lambda pid: "457:still-live",
                        rescan_provider=lambda provider: None,
                        validate_provider_action=lambda provider, action: None):
            retained = self.api["terminal_closed"](value["operation"], now=11)
            self.assertEqual((retained["phase"], retained["terminal_pid"]), ("completed", 457))
            self.assertEqual(self.api["active_operation"]()["operation"], value["operation"])
            with self.assertRaisesRegex(BlockingIOError, "active"):
                self.api["launch_operation"]("mise", now=12)

    def test_live_spawn_with_unavailable_identity_retains_pid_and_blocks_recovery(self):
        class Child:
            pid = 458
        globals_ = self.api["launch_operation"].__globals__
        with patch.dict(globals_, subprocess_popen=lambda argv, **options: Child(),
                        process_identity=lambda pid: None,
                        validate_provider_action=lambda provider, action: None), self.assertRaises(OSError):
            self.api["launch_operation"]("mise", now=10)
        ambiguous = self.api["read_operation"]()
        self.assertEqual((ambiguous["phase"], ambiguous["terminal_pid"], ambiguous["terminal_identity"]),
                         ("interrupted", 458, ""))
        with patch.dict(globals_, process_identity=lambda pid: "458:3"), self.assertRaises(BlockingIOError):
            self.api["reserve_operation"]("mise", "recover", now=11)

    def test_cli_recover_requires_and_consumes_matching_interrupted_state(self):
        previous = self.api["reserve_operation"]("flatpak", "update", now=10)
        self.api["update_operation"](previous["operation"], phase="interrupted", outcome="unknown")
        class Child:
            pid = 789
        globals_ = self.api["main"].__globals__
        with patch.dict(globals_, require_arch=lambda: None,
                        validate_provider_action=lambda provider, action: None,
                        subprocess_popen=lambda argv, **options: Child(), process_identity=lambda pid: "789:2"), \
                patch("sys.stdout", new_callable=io.StringIO) as output:
            self.assertEqual(self.api["main"](["recover", "flatpak"]), 0)
        self.assertIn("\tflatpak\trecover\tlaunched\tpending", output.getvalue())
        saved = self.api["read_operation"]()
        self.assertEqual((saved["action"], saved["recovery_of"], saved["recovery_phase"]),
                         ("recover", previous["operation"], "interrupted"))

    def test_recovery_rejects_absent_completed_failed_wrong_and_healthy_state(self):
        with self.assertRaisesRegex(ValueError, "no matching recoverable"):
            self.api["reserve_operation"]("flatpak", "recover")
        operation = self.api["reserve_operation"]("flatpak", "update", now=10)
        for phase in ("completed", "failed"):
            self.api["update_operation"](operation["operation"], phase=phase,
                                         outcome="succeeded" if phase == "completed" else "failed")
            with self.subTest(phase=phase), self.assertRaisesRegex(ValueError, "no matching recoverable"):
                self.api["reserve_operation"]("flatpak", "recover")
        self.api["update_operation"](operation["operation"], phase="interrupted", outcome="unknown")
        with self.assertRaisesRegex(ValueError, "no matching recoverable"):
            self.api["reserve_operation"]("mise", "recover")

    def test_runner_revalidation_requires_authoritative_recovery_basis(self):
        function = self.api["validate_provider_action"]
        healthy = self.api["ProviderResult"]("flatpak", update_available=True)
        with patch.dict(function.__globals__, scan_flatpak=lambda: healthy):
            with self.assertRaisesRegex(ValueError, "authoritative recovery"):
                function("flatpak", "recover")
            previous = self.api["reserve_operation"]("flatpak", "update", now=10)
            self.api["update_operation"](previous["operation"], phase="interrupted", outcome="unknown")
            self.assertEqual(function("flatpak", "recover"), healthy)
            recovery = self.api["reserve_operation"]("flatpak", "recover", now=11)
            self.assertEqual(function("flatpak", "recover"), healthy)
            self.assertEqual(recovery["recovery_phase"], "interrupted")

    def test_phase_outcome_coherence_rejects_impossible_durable_states(self):
        operation = self.api["reserve_operation"]("system", "update", now=10)
        for phase, outcome in (("completed", "pending"), ("failed", "succeeded"),
                               ("interrupted", "failed"), ("running", "succeeded"),
                               ("closed", "pending"), ("flatpak-user", "pending")):
            with self.subTest(phase=phase, outcome=outcome), self.assertRaisesRegex(ValueError, "invalid operation"):
                self.api["update_operation"](operation["operation"], phase=phase, outcome=outcome)

    def test_recovery_provenance_rejects_cross_provider_phases(self):
        operation = self.api["reserve_operation"]("flatpak", "update", now=10)
        self.api["update_operation"](operation["operation"], phase="system-complete/user-failed",
                                     provider_phase="flatpak-user", outcome="failed")
        recovery = self.api["reserve_operation"]("flatpak", "recover", now=11)
        malformed = (
            {**recovery, "provider": "system", "recovery_provider_phase": "system-native"},
            {**recovery, "provider": "dwm-titus", "recovery_provider_phase": "desktop-starting"},
            {**recovery, "provider": "system", "recovery_phase": "interrupted",
             "recovery_provider_phase": "flatpak-user"},
            {**recovery, "provider": "mise", "recovery_phase": "interrupted",
             "recovery_provider_phase": "system-native"},
        )
        for value in malformed:
            with self.subTest(provider=value["provider"], phase=value["recovery_phase"],
                              provider_phase=value["recovery_provider_phase"]), \
                    self.assertRaisesRegex(ValueError, "invalid operation"):
                self.api["validate_operation"](value)

    def test_missing_optional_provider_is_not_operation_eligible(self):
        function = self.api["validate_provider_action"]
        with patch.dict(function.__globals__, scan_flatpak=lambda: None):
            with self.assertRaisesRegex(ValueError, "unavailable or incompatible"):
                function("flatpak", "update")


class RunnerTests(Environment):
    def setUp(self):
        super().setUp()
        self.api = runpy.run_path(str(RUNNER))
        self.operation = "op-" + "a" * 32

    def test_desktop_authorization_is_owned_only_by_worker(self):
        self.assertNotIn("getpass", self.api)
        self.assertNotIn("validate_sudo_password", self.api)
        self.assertNotIn("prompt_sudo_password", self.api)

    def run_adapter(self, provider, action, responses=None, recovery_basis=("interrupted", "flatpak-system")):
        calls = []
        phases = []
        responses = list(responses or [])
        def command(argv, **options):
            calls.append((argv, options))
            value = responses.pop(0) if responses else ""
            if isinstance(value, Exception):
                raise value
            return value
        with patch.dict(self.api["CENTER"], active_operation=lambda: {"operation": self.operation, "recovery_provider_phase": "system-native"}), \
                patch.dict(self.api["execute_provider"].__globals__, run_command=command, run_protocol_command=command,
                        checkpoint=lambda operation, phase, detail, **k: phases.append(phase),
                        validate_provider_action=lambda provider, action: None,
                        flatpak_recovery_basis=lambda operation: recovery_basis,
                        executable=lambda name: "/usr/bin/" + name,
                        trusted_desktop_helper=lambda: "/usr/bin/dwm-desktop-update"):
            result = self.api["execute_provider"](self.operation, provider, action)
        return result, calls, phases

    def test_terminal_protocol_output_wraps_at_fields_without_splitting_words(self):
        output = io.StringIO()
        self.api["print_terminal_line"](
            "provider\tsecurity\tpartial read-only\tdwm-system-management\t"
            "Bounded read-only observations; inspect individual state details\n",
            output=output,
            width=52,
        )
        lines = output.getvalue().splitlines()
        self.assertGreater(len(lines), 1)
        self.assertTrue(all(len(line) <= 52 for line in lines))
        self.assertIn("dwm-system-management", output.getvalue())
        self.assertNotIn("dwm-system-\nmanagement", output.getvalue())
        self.assertNotIn("\t", output.getvalue())

    def test_plain_provider_output_passes_through_without_packagekit_formatting(self):
        output = io.StringIO()
        self.api["print_terminal_line"]("Updating org.example.App\n", output=output)
        self.assertEqual(output.getvalue(), "Updating org.example.App\n")
        for removed in ("ProgressTracker", "parse_operation_stream", "recover_packagekit",
                        "run_protocol_command", "execute_fedora", "fedora_restart"):
            self.assertNotIn(removed, self.api)

    def test_provider_header_and_step_ansi_formatting(self):
        headers = {
            ("system", "update"): "\033[32m\nUpdate system packages\033[0m\n",
            ("flatpak", "update"): "\033[32m\nUpdate Flatpak packages\033[0m\n",
            ("dwm-titus", "update"): "\033[32m\nUpdate DWM-Titus\033[0m\n",
            ("mise", "update"): "\033[32m\nUpdate mise tools\033[0m\n",
            ("system", "recover"): "\033[32m\nRecover system packages\033[0m\n",
            ("flatpak", "recover"): "\033[32m\nRecover Flatpak packages\033[0m\n",
            ("dwm-titus", "recover"): "\033[32m\nRecover DWM-Titus\033[0m\n",
            ("mise", "recover"): "\033[32m\nRecover mise tools\033[0m\n",
            ("aur", "update"): "\033[32m\nUpdate AUR packages\033[0m\n",
            ("aur", "recover"): "\033[32m\nRecover AUR packages\033[0m\n",
        }
        for (provider, action), expected in headers.items():
            with self.subTest(provider=provider, action=action):
                output = io.StringIO()
                self.api["print_provider_header"](provider, action, output=output)
                self.assertEqual(output.getvalue(), expected)

        step_output = io.StringIO()
        self.api["print_step"]("Updating system Flatpaks", output=step_output)
        self.assertEqual(step_output.getvalue(), "\033[1;34m::\033[0m Updating system Flatpaks...\n")

        complete_output = io.StringIO()
        self.api["print_step"]("System Flatpak update completed", output=complete_output)
        self.assertEqual(complete_output.getvalue(), "\033[1;34m::\033[0m System Flatpak update completed\n")

    def test_result_bounds_multibyte_detail_for_operation_receipt(self):
        center = self.api["CENTER"]
        operation = center["reserve_operation"]("mise", "update")
        result = self.api["result"]("unknown", "interrupted", "\u00e9" * 8192)
        recorded = center["update_operation"](operation["operation"], phase=result["phase"],
            outcome=result["outcome"], detail=result["detail"])
        self.assertEqual(recorded["outcome"], "unknown")
        self.assertEqual(recorded["detail"], "\u00e9" * 4096)

    def news_feed(self, *entries):
        items = "".join(f"<item><title>{title}</title><link>{link}</link><pubDate>{date}</pubDate></item>"
                        for title, link, date in entries)
        return ('<?xml version="1.0" encoding="utf-8"?><rss version="2.0"><channel><title>Arch Linux: Recent news'
                f' updates</title>{items}</channel></rss>').encode()

    def run_system(self, action="update", *, answers="", status=0, lock=(False, False), feed=None,
                   acknowledged=0, receipt=None):
        receipt = receipt or {"operation": self.operation, "detail": "Recovery reserved; last known result: "
                              "pacman was interrupted"}
        calls, acks, phases = [], [], []
        locks = list(lock)

        def update(operation, **changes):
            receipt.update(changes)
            phases.append(changes.get("phase"))

        def native(argv, **options):
            self.assertEqual((receipt["phase"], receipt["provider_phase"]), ("system-executing", "system-native"))
            calls.append((argv, options))
            return status

        def fetch():
            if isinstance(feed, Exception):
                raise feed
            return feed if feed is not None else self.news_feed()

        output = io.StringIO()
        with patch.dict(self.api["CENTER"], active_operation=lambda: receipt, update_operation=update,
                        read_news_ack=lambda: acknowledged, write_news_ack=acks.append), \
                patch.dict(self.api["execute_system"].__globals__,
                           trusted_native_command=lambda path: path,
                           checkpoint=lambda operation, phase, detail, **k: update(operation, phase=phase,
                                                                               provider_phase=phase),
                           pacman_lock_held=lambda: locks.pop(0) if locks else False,
                           fetch_news=fetch), \
                patch.object(subprocess, "call", native):
            value = self.api["execute_system"](self.operation, action, input_stream=io.StringIO(answers),
                                               output=output)
        return value, calls, acks, output.getvalue(), phases

    def test_system_update_runs_interactive_sudo_pacman_syu_without_noconfirm(self):
        for status, outcome, phase in ((0, "succeeded", "completed"), (1, "unknown", "failed"),
                                       (-15, "unknown", "interrupted")):
            with self.subTest(status=status):
                value, calls, acks, _, phases = self.run_system(status=status)
                self.assertEqual(calls, [(["/usr/bin/sudo", "--", "/usr/bin/pacman", "-Syu"], {"cwd": "/"})])
                self.assertNotIn("--noconfirm", calls[0][0])
                self.assertEqual((value["outcome"], value["phase"]), (outcome, phase))
                self.assertEqual(phases, ["preparing", "system-executing"])
                self.assertEqual(acks, [])
                self.assertNotIn("rollback", value["detail"].lower().replace("never rolls back", ""))

    def test_native_allowlist_is_pacman_and_sudo_only(self):
        for path in ("/usr/bin/dnf5", "/usr/bin/paru", "/usr/bin/yay", "/usr/bin/pkexec", "/bin/sh"):
            with self.subTest(path=path), self.assertRaisesRegex(PermissionError, "not allowlisted"):
                self.api["trusted_native_command"](path)

    def test_unread_news_requires_explicit_continue_and_records_acknowledgement(self):
        feed = self.news_feed(("Manual intervention for foo", "https://archlinux.org/news/foo/",
                               "Tue, 01 Oct 2026 10:00:00 +0000"),
                              ("Old item", "https://archlinux.org/news/old/", "Mon, 01 Jan 2024 10:00:00 +0000"))
        newest = 1790848800
        for answer in ("", "n\n", "no\n", "yes please\n"):
            with self.subTest(answer=answer):
                value, calls, acks, text, _ = self.run_system(answers=answer, feed=feed, acknowledged=1704103200)
                self.assertEqual(calls, [])
                self.assertEqual(acks, [])
                self.assertEqual((value["outcome"], value["phase"]), ("failed", "failed"))
                self.assertIn("no packages were changed", value["detail"])
                self.assertIn("Manual intervention for foo", text)
                self.assertNotIn("Old item", text)
        for answer in ("y\n", "YES\n"):
            with self.subTest(answer=answer):
                value, calls, acks, text, _ = self.run_system(answers=answer, feed=feed, acknowledged=1704103200)
                self.assertEqual(len(calls), 1)
                self.assertEqual(acks, [newest])
                self.assertIn("Continue with the system upgrade? [y/N]", text)

    def test_acknowledged_news_skips_prompt_and_unavailable_news_still_asks(self):
        feed = self.news_feed(("Seen", "https://archlinux.org/news/seen/", "Tue, 01 Oct 2026 10:00:00 +0000"))
        value, calls, acks, text, _ = self.run_system(feed=feed, acknowledged=1790848800)
        self.assertEqual((len(calls), acks), (1, []))
        self.assertIn("No unread Arch Linux news", text)
        self.assertNotIn("[y/N]", text)
        failure = self.api["CENTER"]["ScanFailure"]("network", "Network request failed: offline")
        for feed, answer, launched in ((failure, "", 0), (failure, "y\n", 1), (b"<rss><channel>", "y\n", 1),
                                       (b'<!DOCTYPE r [<!ENTITY a "aaaa">]><rss/>', "", 0)):
            with self.subTest(feed=str(feed)[:30], answer=answer):
                value, calls, acks, text, _ = self.run_system(answers=answer, feed=feed)
                self.assertIn("Arch Linux news is unavailable", text)
                self.assertIn("https://archlinux.org/news/", text)
                self.assertIn("[y/N]", text)
                self.assertEqual((len(calls), acks), (launched, []))

    def test_news_text_cannot_inject_terminal_controls(self):
        items = self.api["parse_news"](self.news_feed(
            ("Title\u009b31m\tinjected\nline\u0085", "javascript:alert(1)", "Tue, 01 Oct 2026 10:00:00 +0000"),
            ("No date", "https://archlinux.org/news/x/", "")))
        self.assertEqual(len(items), 1)
        stamp, title, link = items[0]
        self.assertEqual(stamp, 1790848800)
        self.assertFalse(any(ord(char) < 32 or 127 <= ord(char) <= 159 for char in title))
        self.assertEqual(link, "https://archlinux.org/news/")
        for payload in (b"x" * (1024 * 1024 + 1), b"<feed/>", b"not xml",
                        '<?xml version="1.0" encoding="utf-16"?><!DOCTYPE r [<!ENTITY a "a">]><rss/>'.encode("utf-16")):
            with self.subTest(payload=payload[:10]), self.assertRaises(Exception):
                self.api["parse_news"](payload)

    def test_pacman_lock_is_reported_with_guidance_and_never_removed(self):
        value, calls, acks, _, _ = self.run_system(lock=(True,))
        self.assertEqual(calls, [])
        self.assertEqual((value["outcome"], value["phase"]), ("failed", "failed"))
        self.assertIn("/var/lib/pacman/db.lck", value["detail"])
        self.assertIn("fuser", value["detail"])
        self.assertIn("never deletes the lock", value["detail"])
        value, calls, _, _, _ = self.run_system(status=1, lock=(False, True))
        self.assertEqual(len(calls), 1)
        self.assertIn("another package manager is running", value["detail"])
        source = RUNNER.read_text()
        for forbidden in ("unlink(PACMAN_LOCK", "PACMAN_LOCK.unlink", "os.remove(", "rm -f"):
            self.assertNotIn(forbidden, source)

    def test_missing_sudo_fails_cleanly_before_pacman(self):
        def missing(path):
            raise FileNotFoundError(2, "No such file or directory", path)
        output = io.StringIO()
        with patch.dict(self.api["CENTER"], read_news_ack=lambda: 0, update_operation=lambda *a, **k: None), \
                patch.dict(self.api["execute_system"].__globals__, trusted_native_command=missing,
                           checkpoint=lambda *a, **k: None, pacman_lock_held=lambda: False,
                           fetch_news=lambda: self.news_feed()), \
                patch.object(subprocess, "call", side_effect=AssertionError("pacman ran")):
            value = self.api["execute_system"](self.operation, "update", input_stream=io.StringIO(""), output=output)
        self.assertEqual((value["outcome"], value["phase"]), ("failed", "failed"))
        self.assertIn("/usr/bin/sudo", value["detail"])

    def test_system_recovery_reports_last_result_and_offers_fresh_upgrade(self):
        value, calls, _, text, _ = self.run_system("recover", answers="\n")
        self.assertEqual(calls, [])
        self.assertIn("last known result: pacman was interrupted", text)
        self.assertIn("never rolls back", text)
        self.assertIn("sudo pacman -Syu", text)
        self.assertEqual((value["outcome"], value["phase"]), ("unknown", "failed"))
        self.assertIn("remains unknown", value["detail"])
        value, calls, _, _, _ = self.run_system("recover", answers="y\n")
        self.assertEqual(calls[0][0], ["/usr/bin/sudo", "--", "/usr/bin/pacman", "-Syu"])
        self.assertEqual(value["outcome"], "succeeded")
        with self.assertRaisesRegex(ValueError, "active reservation"):
            self.run_system("recover", receipt={"operation": "op-" + "b" * 32, "detail": ""})

    def test_system_recovery_reports_the_durable_last_known_result_end_to_end(self):
        center = self.api["CENTER"]
        previous = center["reserve_operation"]("system", "update")
        center["update_operation"](previous["operation"], phase="interrupted", outcome="unknown",
                                   provider_phase="system-native", detail="pacman was interrupted by a hangup")
        recovery = center["reserve_operation"]("system", "recover")
        center["update_operation"](recovery["operation"], phase="interrupted", outcome="unknown")
        recovery = center["reserve_operation"]("system", "recover")
        self.assertEqual(recovery["detail"], "Recovery reserved; last known result: pacman was interrupted by a hangup")
        held = []
        with patch.dict(self.api["main"].__globals__, set_terminal_identity=lambda: True,
                        completion_hold=held.append), \
                patch.object(subprocess, "call", side_effect=AssertionError("declined recovery ran pacman")), \
                patch("sys.stdin", io.StringIO("n\n")), patch("sys.stdout", new_callable=io.StringIO) as output:
            self.assertEqual(self.api["main"]([recovery["operation"], "system", "recover"]), 1)
        self.assertIn("last known result: pacman was interrupted by a hangup", output.getvalue())
        saved = center["read_operation"]()
        self.assertEqual((saved["phase"], saved["outcome"]), ("failed", "unknown"))
        self.assertIn("remains unknown", held[0]["detail"])

    def test_system_update_preserves_real_pty_output_and_confirmation(self):
        import pty
        import select
        sudo = Path(self.temp.name) / "sudo"
        pacman = Path(self.temp.name) / "pacman"
        sudo.write_text('#!/bin/sh\nshift\nexec "$@"\n')
        sudo.chmod(0o700)
        pacman.write_text("#!" + sys.executable + "\nimport os,sys\n"
                          "assert sys.argv[1:] == ['-Syu'], sys.argv\n"
                          "assert all(os.isatty(fd) for fd in (0,1,2))\n"
                          "print(':: Synchronizing package databases...', flush=True)\n"
                          "print('warning: native stderr', file=sys.stderr, flush=True)\n"
                          "assert input(':: Proceed with installation? [Y/n] ') == 'y'\n"
                          "print('NATIVE COMPLETE', flush=True)\n")
        pacman.chmod(0o700)
        harness = ("import runpy\na=runpy.run_path(" + repr(str(RUNNER)) + ")\n"
                   "g=a['execute_system'].__globals__\n"
                   "g['checkpoint']=lambda *args, **kwargs: None\n"
                   "g['pacman_lock_held']=lambda: False\n"
                   "g['fetch_news']=lambda: b'<rss><channel><item><title>Read me</title><link>https://archlinux.org/news/r/</link>"
                   "<pubDate>Tue, 01 Oct 2026 10:00:00 +0000</pubDate></item></channel></rss>'\n"
                   "a['CENTER']['update_operation']=lambda *args,**kwargs: None\n"
                   "a['CENTER']['read_news_ack']=lambda: 0\n"
                   "a['CENTER']['write_news_ack']=lambda value: None\n"
                   "g['trusted_native_command']=lambda path: " + repr(str(sudo)) + " if path.endswith('/sudo') else "
                   + repr(str(pacman)) + "\n"
                   "r=a['execute_system'](" + repr(self.operation) + ",'update')\n"
                   "assert r['outcome']=='succeeded',r\n")
        master, slave = pty.openpty()
        process = subprocess.Popen([sys.executable, "-c", harness], stdin=slave, stdout=slave, stderr=slave)
        os.close(slave)
        output = bytearray()
        answered = []
        deadline = time.monotonic() + 10
        try:
            while time.monotonic() < deadline:
                if select.select([master], [], [], 0.1)[0]:
                    try:
                        data = os.read(master, 65536)
                    except OSError:
                        break
                    if not data:
                        break
                    output.extend(data)
                    for prompt in (b"Continue with the system upgrade? [y/N] ", b"Proceed with installation? [Y/n] "):
                        if prompt not in answered and prompt in output:
                            os.write(master, b"y\n")
                            answered.append(prompt)
                elif process.poll() is not None:
                    break
            self.assertEqual(process.wait(timeout=2), 0, output.decode(errors="replace"))
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()
            os.close(master)
        for marker in (b"Read me", b"Synchronizing package databases", b"native stderr", b"NATIVE COMPLETE"):
            self.assertIn(marker, output)
        self.assertEqual(len(answered), 2)

    def run_aur(self, action="update", *, euid=1000, helper="/usr/bin/paru", status=0, answers=""):
        receipt = {"operation": self.operation, "detail": "Recovery reserved; last known result: paru failed"}
        calls = []

        def native(argv, **options):
            self.assertEqual((receipt["phase"], receipt["provider_phase"]), ("aur-executing", "aur-helper"))
            calls.append((argv, options))
            return status

        output = io.StringIO()
        with patch.dict(self.api["CENTER"], active_operation=lambda: receipt, aur_helper=lambda: helper,
                        update_operation=lambda operation, **changes: receipt.update(changes)), \
                patch("os.geteuid", return_value=euid), patch.object(subprocess, "call", native):
            value = self.api["execute_aur"](self.operation, action, input_stream=io.StringIO(answers), output=output)
        return value, calls, output.getvalue()

    def test_aur_update_runs_helper_as_invoking_user(self):
        for helper in ("/usr/bin/paru", "/usr/bin/yay"):
            with self.subTest(helper=helper):
                value, calls, _ = self.run_aur(helper=helper)
                self.assertEqual(calls, [([helper, "-Sua"], {"cwd": str(Path.home())})])
                self.assertEqual(value["outcome"], "succeeded")
        value, calls, _ = self.run_aur(status=1)
        self.assertEqual((value["outcome"], value["phase"]), ("unknown", "failed"))
        value, calls, text = self.run_aur("recover", answers="\n")
        self.assertEqual(calls, [])
        self.assertIn("paru failed", text)
        self.assertIn("paru -Sua", text)
        value, calls, _ = self.run_aur("recover", answers="y\n")
        self.assertEqual(calls[0][0], ["/usr/bin/paru", "-Sua"])

    def test_aur_never_runs_as_root_or_through_sudo(self):
        with self.assertRaisesRegex(PermissionError, "never run as root"):
            self.run_aur(euid=0)
        with patch("os.geteuid", return_value=0), \
                patch.dict(self.api["execute_provider"].__globals__,
                           validate_provider_action=lambda *args: self.fail("root AUR run was validated"),
                           execute_aur=lambda *args: self.fail("root AUR run was dispatched")):
            refused = self.api["execute_provider"](self.operation, "aur", "update")
        self.assertEqual((refused["outcome"], refused["phase"]), ("failed", "failed"))
        self.assertIn("never run as root", refused["detail"])
        with self.assertRaisesRegex(FileNotFoundError, "never installs"):
            self.run_aur(helper=None)
        source = RUNNER.read_text()
        aur = source[source.index("def execute_aur("):source.index("def desktop_value(")]
        for forbidden in ("sudo", "pkexec", "--noconfirm", "makepkg"):
            self.assertNotIn('"' + forbidden, aur)

    def test_execute_provider_dispatches_system_without_rediscovery(self):
        called = []
        with patch.dict(self.api["execute_provider"].__globals__,
                        validate_provider_action=lambda provider, action: called.append(provider),
                        execute_system=lambda operation, action: {"provider": "system"},
                        execute_aur=lambda operation, action: {"provider": "aur"}):
            self.assertEqual(self.api["execute_provider"](self.operation, "system", "update"), {"provider": "system"})
            self.assertEqual(self.api["execute_provider"](self.operation, "aur", "update"), {"provider": "aur"})
        self.assertEqual(called, ["aur"])
        with self.assertRaises(ValueError):
            self.api["execute_provider"](self.operation, "fedora", "update")

    def test_run_command_isolates_stderr_from_machine_output(self):
        code = 'import sys; sys.stderr.write("warning: unmanaged\\n"); sys.stdout.write("{\\"ok\\": true}\\n")'
        devnull = os.open(os.devnull, os.O_WRONLY)
        old_stderr = os.dup(2)
        try:
            os.dup2(devnull, 2)
            with contextlib.redirect_stdout(io.StringIO()):
                output = self.api["run_command"]([sys.executable, "-c", code])
        finally:
            os.dup2(old_stderr, 2)
            os.close(old_stderr)
            os.close(devnull)
        self.assertEqual(output.strip(), '{"ok": true}')

    def test_run_command_enforces_read_deadline_and_reaps_child(self):
        code = 'import time; time.sleep(10)'
        with self.assertRaises(TimeoutError):
            self.api["run_command"]([sys.executable, "-c", code], timeout=0.1)

    def test_run_command_timeout_reaps_descendants_after_leader_exit(self):
        pidfile = Path(self.temp.name) / "descendant.pid"
        code = ("import subprocess, sys; from pathlib import Path; "
                "child = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(30)']); "
                "Path(sys.argv[1]).write_text(str(child.pid))")
        try:
            with self.assertRaises(TimeoutError):
                self.api["run_command"]([sys.executable, "-c", code, str(pidfile)], timeout=0.5)
            pid = int(pidfile.read_text())
            for _ in range(100):
                if self.api["CENTER"]["process_identity"](pid) is None:
                    break
                self.api["time"].sleep(0.01)
            self.assertIsNone(self.api["CENTER"]["process_identity"](pid))
        finally:
            if pidfile.exists():
                try:
                    os.kill(int(pidfile.read_text()), 9)
                except ProcessLookupError:
                    pass

    def test_terminal_hangup_and_termination_clean_up_bounded_helpers(self):
        cases = [(signum, mode) for signum in (signal.SIGHUP, signal.SIGTERM)
                 for mode in ("stream", "preflight")]
        for signum, mode in cases:
            with self.subTest(signal=signum, mode=mode):
                pidfile = Path(self.temp.name) / f"helper-{signum}-{mode}.pid"
                helper = ("import os, sys, time; from pathlib import Path; "
                          "Path(sys.argv[1]).write_text(str(os.getpid())); time.sleep(30)")
                code = ("import runpy, sys; api = runpy.run_path(sys.argv[1]); "
                        "api['run_command']([sys.executable, '-c', sys.argv[2], sys.argv[3]])")
                if mode == "preflight":
                    code = ("import runpy, sys; api = runpy.run_path(sys.argv[1]); "
                            "op = 'op-' + 'a' * 32; "
                            "api['main'].__globals__['set_terminal_identity'] = lambda: True; "
                            "api['CENTER']['active_operation'] = lambda: dict(operation=op, provider='mise', action='update'); "
                            "api['CENTER']['update_operation'] = lambda *args, **kwargs: None; "
                            "api['execute_provider'].__globals__['validate_provider_action'] = "
                            "lambda *args: api['CENTER']['run_bounded']([sys.executable, '-c', sys.argv[2], sys.argv[3]]); "
                            "raise SystemExit(api['main']([op, 'mise', 'update']))")
                runner = subprocess.Popen([sys.executable, "-c", code, str(RUNNER), helper, str(pidfile)],
                                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                try:
                    deadline = time.monotonic() + 5
                    while not pidfile.exists() and time.monotonic() < deadline:
                        time.sleep(0.01)
                    self.assertTrue(pidfile.exists(), "bounded helper did not start")
                    runner.send_signal(signum)
                    self.assertEqual(runner.wait(timeout=5), 128 + signum)
                    self.assertIsNone(self.api["CENTER"]["process_identity"](int(pidfile.read_text())))
                finally:
                    if runner.poll() is None:
                        runner.terminate()
                        runner.wait(timeout=5)
                    if pidfile.exists():
                        try:
                            os.kill(int(pidfile.read_text()), signal.SIGKILL)
                        except ProcessLookupError:
                            pass

    def test_run_command_enforces_max_bytes_on_unbounded_line(self):
        code = 'import sys; [sys.stdout.write("x" * 1024) or sys.stdout.flush() for _ in range(10000)]'
        with patch.dict(self.api["CENTER"], MAX_BYTES=2048):
            with self.assertRaisesRegex(ValueError, "byte limit"):
                self.api["run_command"]([sys.executable, "-c", code], timeout=2)

    def test_desktop_uses_trusted_status_check_start_and_recover(self):
        ready = json.dumps({"schema": 1, "state": "available", "installed": "a" * 40,
                            "available": "b" * 40, "canUpdate": True, "detail": "Ready", "restart": "none"})
        done = json.dumps({"schema": 1, "state": "current", "installed": "b" * 40,
                           "available": "b" * 40, "canUpdate": False, "detail": "Done", "restart": "session"})
        result, calls, phases = self.run_adapter("dwm-titus", "update", [ready, ready, done, done])
        self.assertEqual([call[0][1] for call in calls], ["status", "check", "start", "status"])
        self.assertEqual(calls[2][0][2], "b" * 40)
        self.assertEqual((result["outcome"], result["restart"]), ("succeeded", "session"))
        interrupted = json.dumps({**json.loads(ready), "state": "interrupted", "operation": "d" * 32})
        _, calls, _ = self.run_adapter("dwm-titus", "recover", [interrupted, done])
        self.assertEqual([call[0][1] for call in calls], ["status", "recover"])
        self.assertEqual(calls[1][0][2], "d" * 32)
        recovered_state = json.dumps({
            "schema": 1, "state": "failed", "installed": "a" * 40, "available": "b" * 40,
            "canUpdate": False, "detail": "Previous desktop files restored. Log out and back in, then check again.",
            "restart": "session"
        })
        recovered_res, calls, _ = self.run_adapter("dwm-titus", "recover", [interrupted, recovered_state])
        self.assertEqual((recovered_res["outcome"], recovered_res["phase"]), ("succeeded", "completed"))
        already_ready = json.dumps({
            "schema": 1, "state": "available", "installed": "a" * 40, "available": "b" * 40,
            "canUpdate": True, "detail": "A desktop update is available", "restart": "none"
        })
        already_res, calls, _ = self.run_adapter("dwm-titus", "recover", [already_ready])
        self.assertEqual([call[0][1] for call in calls], ["status"])
        self.assertEqual((already_res["outcome"], already_res["phase"]), ("succeeded", "completed"))
        self.assertIn("already recovered", already_res["detail"])

    def test_desktop_recovery_waits_for_independent_active_worker(self):
        for final_state, outcome, phase in (("current", "succeeded", "completed"),
                                          ("failed", "failed", "failed"),
                                          ("interrupted", "unknown", "interrupted")):
            with self.subTest(final_state=final_state), patch("time.sleep") as sleep, \
                    contextlib.redirect_stdout(io.StringIO()):
                responses = [json.dumps({"state": state, "detail": state, "restart": "none"})
                             for state in ("building", "installing", final_state)]
                result, calls, phases = self.run_adapter("dwm-titus", "recover", responses)
                self.assertEqual([call[0][1] for call in calls], ["status", "status", "status"])
                self.assertEqual(phases, ["recovering"])
                self.assertEqual(sleep.call_count, 2)
                self.assertEqual((result["outcome"], result["phase"]), (outcome, phase))

    def test_flatpak_system_first_partial_and_recovery_rechecks_both_scopes(self):
        result, calls, phases = self.run_adapter("flatpak", "update")
        self.assertEqual([call[0][1:] for call in calls], [["update", "--system", "--noninteractive"],
            ["update", "--user", "--noninteractive"]])
        self.assertEqual(result["outcome"], "succeeded")
        self.assertEqual(phases, ["flatpak-system", "flatpak-system-complete", "flatpak-user",
                                  "flatpak-user-complete"])
        result, calls, phases = self.run_adapter("flatpak", "update", ["", subprocess.CalledProcessError(1, ["flatpak"])])
        self.assertEqual(result["phase"], "system-complete/user-failed")
        self.assertNotIn("rollback", result["detail"].lower())
        recovered, recovery_calls, recovery_phases = self.run_adapter("flatpak", "recover")
        updates = [call[0][1:3] for call in recovery_calls if len(call[0]) > 1 and call[0][1] == "update"]
        self.assertEqual(updates, [["update", "--system"], ["update", "--user"]])
        self.assertEqual(recovered["outcome"], "succeeded")
        self.assertEqual(recovery_phases[:4], ["recovering", "flatpak-system",
                                               "flatpak-system-complete", "flatpak-user"])

    def test_flatpak_system_failure_never_starts_user_mutation(self):
        result, calls, phases = self.run_adapter("flatpak", "update",
            [subprocess.CalledProcessError(1, ["flatpak", "update", "--system"])])
        self.assertEqual([call[0][1] for call in calls], ["update"])
        self.assertEqual((result["outcome"], result["phase"]), ("failed", "system-failed"))
        self.assertEqual(phases, ["flatpak-system"])

    def test_flatpak_recovery_preserves_completed_system_and_retries_by_checkpoint(self):
        cases = (("system-failed", "flatpak-system", ["--system", "--user"]),
                 ("system-complete/user-failed", "flatpak-user", ["--user"]),
                 ("interrupted", "flatpak-system", ["--system", "--user"]),
                 ("interrupted", "flatpak-system-complete", ["--user"]),
                 ("interrupted", "flatpak-user", ["--user"]),
                 ("interrupted", "flatpak-user-complete", []),
                 ("interrupted", "recovering", ["--system", "--user"]))
        for recovery_phase, provider_phase, expected in cases:
            with self.subTest(recovery_phase=recovery_phase, provider_phase=provider_phase):
                result, calls, phases = self.run_adapter("flatpak", "recover",
                    recovery_basis=(recovery_phase, provider_phase))
                updates = [call[0][2] for call in calls if len(call[0]) > 2 and call[0][1] == "update"]
                self.assertEqual(updates, expected)
                self.assertEqual(result["outcome"], "succeeded")
                self.assertNotIn("rollback", result["detail"].lower())

    def test_mise_uses_managed_inventory_and_preserves_cooldown(self):
        inventory = json.dumps({"node": [{"version": "20.0.0", "installed": True, "requested_version": "20"},
                                          {"version": "22.0.0", "installed": True, "requested_version": "22"}]})
        result, calls, phases = self.run_adapter("mise", "update", [inventory, "", inventory])
        self.assertEqual(calls[0][0][1:], ["ls", "--current", "--installed", "--json"])
        self.assertEqual(calls[1][0][1:], ["upgrade", "--", "node"])
        self.assertNotIn("MISE_MINIMUM_RELEASE_AGE", calls[1][0])
        self.assertEqual(result["outcome"], "succeeded")
        self.assertEqual(phases, ["mise-inventory", "mise-update", "mise-recheck"])
        result, calls, phases = self.run_adapter("mise", "recover", [inventory, "", inventory])
        self.assertEqual(phases, ["mise-inventory", "recovering", "mise-update", "mise-recheck"])

    def test_completion_prompt_for_success_and_failure_and_test_stream(self):
        output_ok = io.StringIO()
        self.api["completion_hold"]({"outcome": "succeeded", "detail": "All packages updated"},
                                    input_stream=io.StringIO("x"), output=output_ok)
        self.assertIn("\033[1;32m==>\033[0m All packages updated", output_ok.getvalue())
        self.assertIn("\033[32m● \033[0mDone! Press any key to close...", output_ok.getvalue())

        output_fail = io.StringIO()
        self.api["completion_hold"]({"outcome": "failed", "detail": "Transaction failed"},
                                    input_stream=io.StringIO("x"), output=output_fail)
        self.assertIn("\033[1;31m==> ERROR:\033[0m Transaction failed", output_fail.getvalue())
        self.assertIn("\033[32m● \033[0mDone! Press any key to close...", output_fail.getvalue())

    def test_completion_hold_uses_cbreak_on_tty(self):
        calls = []
        class MockTTYStream(io.StringIO):
            def isatty(self):
                return True
            def fileno(self):
                return 42

        stream = MockTTYStream("q")
        output = io.StringIO()
        with patch.object(sys, "stdin", stream), \
             patch("tty.setcbreak", lambda fd: calls.append(("setcbreak", fd))), \
             patch("termios.tcgetattr", lambda fd: ["mock_settings"]), \
             patch("termios.tcsetattr", lambda fd, when, settings: calls.append(("tcsetattr", fd, when, settings))):
            self.api["completion_hold"]({"detail": "All good"}, output=output)
        self.assertEqual(calls, [("setcbreak", 42), ("tcsetattr", 42, termios.TCSADRAIN, ["mock_settings"])])

    def test_runner_main_commits_terminal_state_then_holds_for_injected_key(self):
        operation = self.api["CENTER"]["reserve_operation"]("mise", "update", now=10)
        held = []
        def hold(value):
            output = io.StringIO()
            self.api["completion_hold"](value, input_stream=io.StringIO("k"), output=output)
            held.append(output.getvalue())
        globals_ = self.api["main"].__globals__
        with patch.dict(globals_, execute_provider=lambda *args: {
                "outcome": "succeeded", "phase": "completed", "detail": "Verified", "restart": "none"},
                completion_hold=hold, set_terminal_identity=lambda: True), \
                patch.dict(self.api["CENTER"], rescan_provider=lambda provider: None), \
                patch("sys.stdout", new_callable=io.StringIO) as stdout_capture:
            self.assertEqual(self.api["main"]([operation["operation"], "mise", "update"]), 0)
        self.assertIn("\033[32m\nUpdate mise tools\033[0m\n", stdout_capture.getvalue())
        saved = self.api["CENTER"]["read_operation"]()
        self.assertEqual((saved["phase"], saved["outcome"]), ("completed", "succeeded"))
        self.assertIn("\033[32m● \033[0mDone! Press any key to close...", held[0])

    def test_terminal_outcome_keeps_active_slot_through_success_and_failure_hold(self):
        for outcome, phase, code in (("succeeded", "completed", 0), ("failed", "failed", 1), ("unknown", "failed", 1)):
            with self.subTest(outcome=outcome):
                operation = self.api["CENTER"]["reserve_operation"]("system", "update", now=10)
                observed = []
                def hold(_value):
                    active = self.api["CENTER"]["active_operation"]()
                    observed.append((active["phase"], active["outcome"]))
                    with self.assertRaises(BlockingIOError):
                        self.api["CENTER"]["reserve_operation"]("mise", "update", now=11)
                    output = io.StringIO()
                    center_main = self.api["CENTER"]["main"]
                    with patch.dict(center_main.__globals__, require_arch=lambda: None), \
                            patch("sys.stdout", output):
                        self.assertEqual(center_main(["active"]), 0)
                    self.assertIn("\t" + phase + "\t" + outcome, output.getvalue())
                globals_ = self.api["main"].__globals__
                with patch.dict(globals_, execute_provider=lambda *args: {
                        "outcome": outcome, "phase": phase, "detail": "Terminal result", "restart": "none"},
                        completion_hold=hold, set_terminal_identity=lambda: True), \
                        patch.dict(self.api["CENTER"], rescan_provider=lambda provider: self.fail("completion must not block on discovery")), \
                        patch("sys.stdout", new_callable=io.StringIO):
                    self.assertEqual(self.api["main"]([operation["operation"], "system", "update"]), code)
                self.assertEqual(observed, [(phase, outcome)])
                with patch.dict(self.api["CENTER"]["terminal_closed"].__globals__,
                                process_identity=lambda pid: None, rescan_provider=lambda provider: None):
                    closed = self.api["CENTER"]["terminal_closed"](operation["operation"], now=12)
                self.assertEqual(closed["phase"], "closed")

    def test_runner_interruption_retains_last_durable_provider_phase(self):
        operation = self.api["CENTER"]["reserve_operation"]("mise", "update", now=10)
        def fail(operation_id, provider, action):
            self.api["checkpoint"](operation_id, "mise-update", "Mutation dispatched")
            raise OSError("connection lost")
        globals_ = self.api["main"].__globals__
        with patch.dict(globals_, execute_provider=fail, completion_hold=lambda value: None,
                        set_terminal_identity=lambda: True), \
                patch.dict(self.api["CENTER"], rescan_provider=lambda provider: None), \
                patch("sys.stdout", new_callable=io.StringIO):
            self.assertEqual(self.api["main"]([operation["operation"], "mise", "update"]), 1)
        saved = self.api["CENTER"]["read_operation"]()
        self.assertEqual((saved["phase"], saved["provider_phase"], saved["outcome"]),
                         ("interrupted", "mise-update", "unknown"))

    def test_fixed_terminal_identity_is_token_free_and_rejects_unusable_window(self):
        output = io.StringIO()
        self.assertFalse(self.api["set_terminal_identity"](
            {"DISPLAY": ":1", "WINDOWID": "$(touch injected)"}, output))
        self.assertEqual(self.api["TERMINAL_TITLE"], "dwm update center")
        self.assertEqual(self.api["TERMINAL_INSTANCE"], b"dwm-update-center")
        self.assertEqual(self.api["TERMINAL_CLASS"], b"DwmUpdateCenter")
        self.assertNotIn(self.operation, output.getvalue())

    def test_tiled_terminal_keeps_its_title_when_runner_starts(self):
        output = io.StringIO()
        self.assertTrue(self.api["set_terminal_identity"](
            {"DWM_UPDATE_CENTER_TERMINAL_IDENTITY": "1", "DWM_UPDATE_CENTER_WINDOW_MODE": "tiled"}, output))
        self.assertEqual(output.getvalue(), "\033]0;dwm update center tiled\007")

    def test_terminal_wrapper_identity_is_accepted_without_windowid(self):
        output = io.StringIO()
        self.assertTrue(self.api["set_terminal_identity"](
            {"DWM_UPDATE_CENTER_TERMINAL_IDENTITY": "1"}, output))
        self.assertIn("dwm update center", output.getvalue())

    def test_fixed_x11_title_and_class_are_applied_without_provider_input(self):
        calls = []
        class Function:
            def __init__(self, name, result):
                self.name, self.result = name, result
            def __call__(self, *args):
                calls.append((self.name, args))
                return self.result
        class Library:
            XOpenDisplay = Function("open", 1)
            XStoreName = Function("title", 1)
            XSetClassHint = Function("class", 1)
            XSync = Function("sync", 0)
            XCloseDisplay = Function("close", 0)
        output = io.StringIO()
        with patch.object(self.api["ctypes"], "CDLL", return_value=Library()):
            self.assertTrue(self.api["set_terminal_identity"](
                {"DISPLAY": ":9", "WINDOWID": "42", "PROVIDER": "$(bad)"}, output))
        self.assertEqual([name for name, _ in calls], ["open", "title", "class", "sync", "close"])
        self.assertEqual(calls[1][1][2], b"dwm update center")
        hint = calls[2][1][2]._obj
        self.assertEqual((hint.res_name, hint.res_class), (b"dwm-update-center", b"DwmUpdateCenter"))
        self.assertNotIn("bad", output.getvalue())

    def test_completion_hold_custom_status_banners(self):
        cases = [
            (
                {"outcome": "succeeded", "detail": "Desktop update installed, verified, and active."},
                "\033[1;32mUpdate Installed Successfully!\033[0m",
            ),
            (
                {"outcome": "succeeded", "detail": "Installed and verified. Log out and back in to activate the updated desktop."},
                "\033[1;32mUpdate Installed Successfully! \033[1;33mRestart required, or Log out and back in for update to take effect.\033[0m",
            ),
            (
                {"outcome": "succeeded", "detail": "Files installed and verified, but Quickshell did not respond. Log out and back in."},
                "\033[1;33mUpdate Files Installed, but Quickshell restart timed out, \033[1;31mPlease Log out and back in.\033[0m",
            ),
            (
                {"outcome": "succeeded", "detail": "Previous desktop files restored. Log out and back in, then check again."},
                "\033[1;32mRecovery completed, \033[1;31mPlease Log out and back in for recovery to take effect.\033[0m",
            ),
        ]
        for val, expected_text in cases:
            output = io.StringIO()
            self.api["completion_hold"](val, input_stream=io.StringIO("q"), output=output)
            self.assertIn(expected_text, output.getvalue())
            self.assertIn("\033[32m● \033[0mDone! Press any key to close...", output.getvalue())

    def test_desktop_status_dots_and_percentage_formatting(self):
        output = io.StringIO()
        formatter = self.api["DesktopStatusFormatter"](output=output)

        # Indeterminate step with cycling dots (1 to 5 dots, then reset to 1)
        formatter.update("Creating backup.....", percent=-1)
        self.assertEqual(output.getvalue(), "\r\033[KCreating backup.")

        formatter.update("Creating backup.....", percent=-1)
        self.assertEqual(output.getvalue(), "\r\033[KCreating backup.\r\033[KCreating backup. .")

        formatter.update("Creating backup.....", percent=-1)
        formatter.update("Creating backup.....", percent=-1)
        formatter.update("Creating backup.....", percent=-1)
        # 5th update should have 5 dots
        self.assertEqual(
            output.getvalue().split("\r\033[K")[-1],
            "Creating backup. . . . .",
        )

        formatter.update("Creating backup.....", percent=-1)
        # 6th update resets to 1 dot
        self.assertEqual(
            output.getvalue().split("\r\033[K")[-1],
            "Creating backup.",
        )

        # Transition to new step emits newline first
        formatter.update("Fetching Upstream.....", percent=-1)
        self.assertIn("Creating backup.\n\r\033[KFetching Upstream.", output.getvalue())

        # Percentage step formats in-place with green badge
        formatter.update("Building", percent=20)
        self.assertIn("\n\r\033[KBuilding \033[32m[ 20%]\033[0m", output.getvalue())

        formatter.close()
        self.assertTrue(output.getvalue().endswith("\n"))


class RootHelperAuthTests(unittest.TestCase):
    def setUp(self):
        self.root_api = runpy.run_path(str(ROOT / "scripts/dwm-desktop-update-root"))

    def test_caller_uid_supports_pkexec_and_sudo(self):
        self.assertIn("caller_uid", self.root_api)
        caller_uid = self.root_api["caller_uid"]
        with patch.dict(os.environ, {"PKEXEC_UID": "1000"}, clear=True):
            self.assertEqual(caller_uid(), 1000)
        with patch.dict(os.environ, {"SUDO_UID": "1001"}, clear=True):
            self.assertEqual(caller_uid(), 1001)
        with patch.dict(os.environ, {"PKEXEC_UID": "1000", "SUDO_UID": "1001"}, clear=True):
            self.assertEqual(caller_uid(), 1000)
        with patch.dict(os.environ, {"PKEXEC_UID": "", "SUDO_UID": ""}, clear=True):
            self.assertIsNone(caller_uid())
        with patch.dict(os.environ, {"SUDO_UID": "abc"}, clear=True):
            self.assertIsNone(caller_uid())
        with patch.dict(os.environ, {}, clear=True):
            self.assertIsNone(caller_uid())


class DesktopUpdateAuthorizeWordingTests(unittest.TestCase):
    def setUp(self):
        self.update_api = runpy.run_path(str(ROOT / "scripts/dwm-desktop-update"))

    def test_authorize_detail_omits_legacy_settings_dialog_message(self):
        state = Path("/tmp")
        value = {}
        saved_details = []

        def fake_save_status(s, v, **kwargs):
            if "detail" in kwargs:
                saved_details.append(kwargs["detail"])
            v.update(kwargs)
            return v

        class FakePrivileged:
            started = False
            def start(self):
                self.started = True
            def request(self, action, *args, **kwargs):
                return "ok"

        with patch.dict(self.update_api["authorize"].__globals__, {"save_status": fake_save_status}):
            self.update_api["authorize"](state, value, FakePrivileged(), "begin")

        self.assertTrue(len(saved_details) >= 1)
        first_detail = saved_details[0]
        self.assertNotIn("Settings closes to reveal the password dialog", first_detail)
        self.assertEqual(first_detail, "Administrator authorization: prepare the desktop update.")


if __name__ == "__main__":
    unittest.main()
