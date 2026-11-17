#!/usr/bin/env python3
"""Build and install the current user's AquaSKK guard (requires Apple CLT)."""
import os
from pathlib import Path
import plistlib
import subprocess
import tempfile

LABEL = "local.reoring.aquaskk-guard"


def main():
    home = Path.home()
    binary = home / ".local/bin/aquaskk-guard"
    plist = home / "Library/LaunchAgents" / f"{LABEL}.plist"
    domain = f"gui/{os.getuid()}"
    service = f"{domain}/{LABEL}"
    binary.parent.mkdir(parents=True, exist_ok=True)
    plist.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="aquaskk-guard-", dir=binary.parent) as tmp:
        built = Path(tmp) / "aquaskk-guard"
        subprocess.run([
            "/usr/bin/xcrun", "swiftc", "-O", str(Path(__file__).with_name("main.swift")),
            "-o", str(built),
        ], check=True)
        subprocess.run(["/usr/bin/codesign", "--force", "--sign", "-", str(built)], check=True)
        loaded = subprocess.run(["/bin/launchctl", "print", service], capture_output=True).returncode == 0
        old_binary = binary.read_bytes() if binary.exists() else None
        old_plist = plist.read_bytes() if plist.exists() else None
        if loaded:
            subprocess.run(["/bin/launchctl", "bootout", service], check=True)
        try:
            os.replace(built, binary)
            payload = {
                "Label": LABEL,
                "ProgramArguments": [str(binary)],
                "RunAtLoad": True,
                "KeepAlive": True,
                "LimitLoadToSessionType": "Aqua",
                "ProcessType": "Background",
                "ThrottleInterval": 10,
            }
            temporary_plist = Path(tmp) / "agent.plist"
            temporary_plist.write_bytes(plistlib.dumps(payload))
            temporary_plist.chmod(0o644)
            os.replace(temporary_plist, plist)
            subprocess.run(["/bin/launchctl", "enable", service], check=True)
            subprocess.run(["/bin/launchctl", "bootstrap", domain, str(plist)], check=True)
        except BaseException:
            subprocess.run(["/bin/launchctl", "bootout", service], capture_output=True)
            if old_binary is not None:
                binary.write_bytes(old_binary)
                binary.chmod(0o755)
            else:
                binary.unlink(missing_ok=True)
            if old_plist is not None:
                plist.write_bytes(old_plist)
            else:
                plist.unlink(missing_ok=True)
            if loaded:
                subprocess.run(["/bin/launchctl", "bootstrap", domain, str(plist)], check=True)
            raise
    print(f"Installed and started {service}")
    subprocess.run([str(binary), "--status"], check=True)


if __name__ == "__main__":
    main()
