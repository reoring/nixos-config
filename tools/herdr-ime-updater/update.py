#!/usr/bin/env python3
"""Build and install Herdr releases with the local IME Control-key fix."""
import argparse
import datetime
import fcntl
import json
import os
from pathlib import Path
import platform
import plistlib
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import time
import tomllib
import urllib.request

REPOSITORY = "https://github.com/herdrdev/herdr-app.git"
LATEST = "https://releases.herdr.dev/app/latest.json"
TEST = "ime_activation_keys_precede_terminal_control_keys"
PATCH = Path(__file__).resolve().with_name("ime-control.patch")


def run(*args, cwd=None, env=None, capture=False):
    print("+", shlex.join(str(a) for a in args), flush=True)
    result = subprocess.run([str(a) for a in args], cwd=cwd, env=env,
                            text=True, stdout=subprocess.PIPE if capture else None,
                            check=True)
    if capture:
        print(result.stdout, end="", flush=True)
        return result.stdout


def running(app):
    pattern = "^" + re.escape(str(app / "Contents/MacOS/Herdr")) + "$"
    result = subprocess.run(["/usr/bin/pgrep", "-f", pattern], capture_output=True)
    if result.returncode not in (0, 1):
        raise RuntimeError("Cannot determine whether Herdr is running")
    return result.returncode == 0


def stop(app):
    if not running(app):
        return
    # The app saves its window state; herdr-core and terminals are left running.
    run("osascript", "-e", f"tell application {json.dumps(str(app))} to quit")
    deadline = time.monotonic() + 15
    while running(app):
        if time.monotonic() >= deadline:
            raise RuntimeError("Herdr did not quit; refusing to replace its bundle")
        time.sleep(0.2)


def launch_and_check(app):
    # Refresh the moved bundle and avoid Launch Services' stale process record
    # immediately after quit. stop() has already waited for that process to exit.
    run("/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister",
        "-f", app)
    run("open", "-n", "-a", app)
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        try:
            result = subprocess.run([str(app / "Contents/MacOS/Herdr"), "status"],
                                    capture_output=True, text=True, timeout=6)
            if result.returncode == 0:
                status = json.loads(result.stdout)
                if isinstance(status, dict) and "layout" in status:
                    print("Herdr started:", json.dumps(status, ensure_ascii=False), flush=True)
                    return
        except (subprocess.TimeoutExpired, json.JSONDecodeError):
            pass
        time.sleep(0.5)
    raise RuntimeError("The new Herdr did not answer its status command")


def make_bundle(source, binary, destination, version):
    contents = destination / "Contents"
    (contents / "MacOS").mkdir(parents=True)
    (contents / "Resources").mkdir()
    shutil.copy2(binary, contents / "MacOS/Herdr")
    for name, src in [("Herdr.icns", source / "assets/icons/Herdr.icns"),
                      ("LICENSE", source / "LICENSE"),
                      ("THIRD-PARTY-NOTICES", source / "THIRD-PARTY-NOTICES")]:
        shutil.copy2(src, contents / "Resources" / name)
    info = {
        "CFBundleExecutable": "Herdr", "CFBundleIdentifier": "dev.herdr.app",
        "CFBundleName": "Herdr", "CFBundleDisplayName": "Herdr",
        "CFBundleIconFile": "Herdr", "CFBundlePackageType": "APPL",
        "CFBundleShortVersionString": version, "CFBundleVersion": version,
        "NSPrincipalClass": "NSApplication", "NSHighResolutionCapable": True,
        "NSMicrophoneUsageDescription": "Terminal programs running in Herdr can use the microphone, for example for voice input.",
        "NSCameraUsageDescription": "Terminal programs running in Herdr can use the camera.",
        "NSAppleEventsUsageDescription": "Terminal programs running in Herdr can use AppleScript to control other apps.",
        "LSEnvironment": {},
    }
    with (contents / "Info.plist").open("wb") as output:
        plistlib.dump(info, output)
    run("codesign", "--force", "--sign", "-", destination)
    run("codesign", "--verify", "--deep", "--strict", destination)


def install(bundle, app):
    # Stage on the destination volume: both replacement and rollback are renames.
    with tempfile.TemporaryDirectory(prefix=".herdr-ime-stage-", dir=app.parent) as directory:
        staged = Path(directory) / "Herdr.app"
        shutil.copytree(bundle, staged)
        run("codesign", "--verify", "--deep", "--strict", staged)
        stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S-%f")
        backup = app.parent / ".herdr-ime-backups" / stamp / "Herdr.app"
        backup.parent.mkdir(parents=True)
        was_running = running(app)
        stop(app)
        app.rename(backup)
        try:
            staged.rename(app)
            launch_and_check(app)
        except BaseException:
            # Never discard the previous application, including on Ctrl+C.
            if app.exists():
                stop(app)
                app.rename(Path(directory) / "failed-Herdr.app")
            backup.rename(app)
            if was_running:
                launch_and_check(app)
            raise
        print(f"Installed: {app}\nPrevious app: {backup}", flush=True)


def update(args, cache):
    if args.version == "latest":
        request = urllib.request.Request(LATEST, headers={"User-Agent": "herdr-ime-update"})
        with urllib.request.urlopen(request, timeout=30) as response:
            tag = "v" + json.load(response)["version"]
    else:
        tag = args.version if args.version.startswith("v") else "v" + args.version
    if not re.fullmatch(r"v\d+\.\d+\.\d+(?:-[A-Za-z0-9.-]+)?", tag):
        raise RuntimeError(f"Unsupported release tag: {tag!r}")
    print(f"Release: {tag}", flush=True)
    repo = cache / "repository.git"
    if not repo.exists():
        run("git", "init", "--bare", repo)
        run("git", "--git-dir", repo, "remote", "add", "origin", REPOSITORY)
    run("git", "--git-dir", repo, "fetch", "--depth", "1", "origin", f"refs/tags/{tag}:refs/tags/{tag}")
    with tempfile.TemporaryDirectory(prefix="build-", dir=cache) as directory:
        source = Path(directory) / "source"
        run("git", "clone", "--shared", "--no-checkout", repo, source)
        run("git", "checkout", "--detach", tag, cwd=source)
        # --check does not modify source. No fuzzy patching or dropping hunks.
        run("git", "apply", "--check", PATCH, cwd=source)
        if args.check:
            print("Patch applies cleanly; installed application unchanged.")
            return
        run("git", "apply", PATCH, cwd=source)
        run("git", "submodule", "update", "--init", "--recursive", "--depth", "1", cwd=source)
        env = os.environ.copy()
        env.pop("HERDR_APP_RELEASE", None)  # Preserve the fix: no release auto-updater.
        env.pop("HERDR_RELEASES_URL", None)
        target = Path(env.get("CARGO_TARGET_DIR", str(cache / "target"))).expanduser().resolve()
        env["CARGO_TARGET_DIR"] = str(target)
        env["CARGO_BUILD_TARGET"] = "aarch64-apple-darwin"
        cargo = ["cargo", f"+{args.toolchain}"]
        run(*cargo, "build", "--release", "--locked", cwd=source, env=env)
        result = run(*cargo, "test", "--release", "--locked", "-p", "gpui-pre-macos",
                     "--lib", TEST, cwd=source, env=env, capture=True)
        if "1 passed; 0 failed" not in result:
            raise RuntimeError("Expected IME regression test did not run successfully")
        version = tomllib.loads((source / "Cargo.toml").read_text())["package"]["version"]
        if version != tag.removeprefix("v"):
            raise RuntimeError(f"Release tag/package version mismatch: {tag} / {version}")
        binary = target / "aarch64-apple-darwin/release/herdr-app"
        run(binary, "--version")
        bundle = Path(directory) / "Herdr.app"
        make_bundle(source, binary, bundle, version)
        install(bundle, args.app)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("version", nargs="?", default="latest", help="release tag/version (default: latest stable)")
    parser.add_argument("--check", action="store_true", help="check patch applicability only; do not build or install")
    parser.add_argument("--toolchain", default="1.95.0", help="installed Rust toolchain (default: 1.95.0)")
    parser.add_argument("--app", type=Path, default=Path("/Applications/Herdr.app"), help="existing Herdr bundle to replace")
    args = parser.parse_args()
    args.app = args.app.expanduser().absolute()
    if platform.system() != "Darwin" or platform.machine() != "arm64":
        parser.error("This updater supports Apple Silicon macOS only")
    if args.app.is_symlink() or not (args.app / "Contents/MacOS/Herdr").is_file():
        parser.error("--app must point to an existing, non-symlink Herdr.app bundle")
    cache = Path.home() / "Library/Caches/herdr-ime-updater"
    cache.mkdir(parents=True, exist_ok=True)
    with (cache / "update.lock").open("w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            parser.error("Another herdr-ime-update is already running")
        update(args, cache)


if __name__ == "__main__":
    try:
        main()
    except (Exception, KeyboardInterrupt) as error:
        print(f"Update stopped: {error}", file=sys.stderr)
        sys.exit(1)
