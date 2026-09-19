#!/usr/bin/env python3
"""Minimal Enigma client for Icon Studio machine API.

Transport: temporary request file + `api --request FILE --json`.
Workspace: pass Enigma root via workspace_root or ICONSTUDIO_WORKSPACE_ROOT.
"""

from __future__ import annotations

import json
import os
import subprocess
import tempfile
from pathlib import Path
from typing import Any


class IconStudioClient:
    def __init__(
        self,
        cli_path: str | Path | None = None,
        workspace_root: str | Path | None = None,
        timeout: float | None = 300.0,
    ) -> None:
        root = Path(__file__).resolve().parents[1]
        self.cli = Path(cli_path) if cli_path else root / "scripts" / "iconstudio"
        env_root = os.environ.get("ICONSTUDIO_WORKSPACE_ROOT", "")
        self.workspace_root = Path(workspace_root) if workspace_root else (Path(env_root) if env_root else None)
        self.timeout = timeout

    def _execute(self, request: dict[str, Any]) -> dict[str, Any]:
        cmd = [str(self.cli), "api", "--json"]
        if self.workspace_root is not None:
            cmd.extend(["--workspace-root", str(self.workspace_root)])
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as handle:
            json.dump(request, handle)
            request_path = handle.name
        cmd.extend(["--request", request_path])
        try:
            proc = subprocess.run(
                cmd,
                text=True,
                capture_output=True,
                check=False,
                timeout=self.timeout,
            )
        except subprocess.TimeoutExpired as exc:
            raise TimeoutError(
                f"Icon Studio exceeded timeout of {self.timeout} seconds"
            ) from exc
        finally:
            Path(request_path).unlink(missing_ok=True)
        if not proc.stdout.strip():
            raise RuntimeError(proc.stderr or "Icon Studio returned no JSON")
        return json.loads(proc.stdout.strip())

    def capabilities(self) -> dict[str, Any]:
        return self._execute({"schema_version": 1, "operation": "capabilities"})

    def schema(self) -> dict[str, Any]:
        return self._execute({"schema_version": 1, "operation": "schema"})

    def inspect_asset(self, asset: str, asset_id: str | None = None) -> dict[str, Any]:
        req: dict[str, Any] = {
            "schema_version": 1,
            "operation": "inspect_asset",
            "asset": asset,
        }
        if asset_id:
            req["asset_id"] = asset_id
        return self._execute(req)

    def render_asset(
        self,
        asset: str,
        purpose: str,
        *,
        asset_id: str | None = None,
        force: bool = False,
        hints: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        req: dict[str, Any] = {
            "schema_version": 1,
            "operation": "render_asset",
            "asset": asset,
            "purpose": purpose,
        }
        if asset_id:
            req["asset_id"] = asset_id
        if force:
            req["force"] = True
        if hints:
            req["hints"] = hints
        return self._execute(req)

    def render_asset_set(
        self,
        asset: str,
        outputs: list[str],
        *,
        asset_id: str | None = None,
        force: bool = False,
        hints: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        req: dict[str, Any] = {
            "schema_version": 1,
            "operation": "render_asset_set",
            "asset": asset,
            "outputs": outputs,
        }
        if asset_id:
            req["asset_id"] = asset_id
        if force:
            req["force"] = True
        if hints:
            req["hints"] = hints
        return self._execute(req)

    def validate_output(self, asset: str, output: str, purpose: str) -> dict[str, Any]:
        return self._execute(
            {
                "schema_version": 1,
                "operation": "validate_output",
                "asset": asset,
                "output": output,
                "purpose": purpose,
            }
        )

    def explain_result(self, job_id: str) -> dict[str, Any]:
        return self._execute(
            {
                "schema_version": 1,
                "operation": "explain_result",
                "job_id": job_id,
            }
        )


if __name__ == "__main__":
    client = IconStudioClient()
    print(json.dumps(client.capabilities(), indent=2))
