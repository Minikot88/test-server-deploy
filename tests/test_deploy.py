"""Offline regression tests. External commands are isolated shell fixtures."""
import os
import shutil
from pathlib import Path
import subprocess
import tempfile
import unittest

PROJECT = Path(__file__).resolve().parents[1]
_git_bash = Path("C:/Program Files/Git/usr/bin/bash.exe")
BASH = os.environ.get("TEST_BASH") or (str(_git_bash) if os.name == "nt" and _git_bash.exists() else shutil.which("bash"))
if not BASH:
    raise SystemExit("Bash is required for offline deployment checks")
REPLACEMENTS = {
    "CHANGE_ME_REGISTRY": "registry.example.invalid",
    "CHANGE_ME_API_IMAGE": "sample-api",
    "CHANGE_ME_WEB_IMAGE": "sample-web",
    "CHANGE_ME_SSH_HOST": "host.example.invalid",
    "CHANGE_ME_SSH_USER": "demo",
    "CHANGE_ME_SSH_PORT": "22",
    "CHANGE_ME_NAMESPACE": "sample-prod",
    "CHANGE_ME_API_DEPLOYMENT": "sample-api",
    "CHANGE_ME_WEB_DEPLOYMENT": "sample-web",
    "CHANGE_ME_API_CLUSTER_IP": "10.43.0.10",
    "CHANGE_ME_WEB_CLUSTER_IP": "10.43.0.11",
    "CHANGE_ME_API_DOMAIN": "api.example.invalid",
    "CHANGE_ME_WEB_DOMAIN": "web.example.invalid",
    "CHANGE_ME_API_RUNTIME_SECRET": "sample-runtime",
}


class DeploymentTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="example-check-")
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.bin = self.base / "bin"
        self.bin.mkdir()
        self.log = self.base / "commands.log"
        self.env = os.environ.copy()
        self.env.pop("BASH_ENV", None)
        self.env["PATH"] = os.pathsep.join([str(self.bin), str(Path(BASH).parent), os.defpath])
        self.env["CALL_LOG"] = self.log.as_posix()
        self.env["NEW_IMAGE"] = "registry.example.invalid/sample-api@sha256:" + "a" * 64
        for folder in ("backend", "frontend"):
            (self.base / folder).mkdir()
            (self.base / folder / "Dockerfile").write_text("FROM scratch\n")
        self.stub("git", '''
case "$*" in
  'status --porcelain') ;;
  'branch --show-current') echo main;;
  'rev-parse --short HEAD') echo abc1234;;
  'rev-parse HEAD'|'rev-parse origin/main') echo abc1234;;
  'fetch origin --quiet') ;;
  *) exit 81;;
esac
''')
        self.stub("docker", '''
case "$*" in
  'buildx build '*) ;;
  'buildx imagetools inspect '*) printf 'Digest: sha256:%064d\n' 0 | sed 's/0/a/g';;
  *) exit 82;;
esac
''')
        self.stub("curl", '''
if [[ "${SCENARIO:-}" == public_redirect && "$*" == *https://* ]]; then
  printf 301
else
  printf 200
fi
''')
        self.stub("sleep", ":\n")
        self.stub("ssh", 'for arg; do remote_command="$arg"; done\nbash --noprofile --norc -c "$remote_command"\n')
        self.stub("sudo", '''
if [[ "$1" == -v ]]; then exit 0; fi
[[ "$1" == kubectl ]] || exit 83
shift
case "$*" in
  'get deployment '*'containers[0].name'*) echo "$APP";;
  'get deployment '*envFrom*)
    if [[ "${SCENARIO:-}" == key_ref ]]; then :
    elif [[ "${SCENARIO:-}" == wrong_ref ]]; then echo other-runtime
    else echo sample-runtime; fi;;
  'get deployment '*valueFrom*)
    if [[ "${SCENARIO:-}" == key_ref ]]; then echo sample-runtime; fi;;
  'get secret '*)
    [[ "${SCENARIO:-}" == missing_secret ]] && exit 1
    if [[ "${SCENARIO:-}" == missing_key ]]; then echo JWT_SECRET; else printf 'DATABASE_URL\nJWT_SECRET\n'; fi;;
  'get deployment '*image*) echo "$NEW_IMAGE";;
  'set image '*) ;;
  'rollout status '*) ;;
  *) echo "Unexpected kubectl args: $*" >&2; exit 84;;
esac
''')

    def stub(self, name, body):
        log = name if name == "ssh" else name + " $*"
        (self.bin / name).write_text(
            '#!/usr/bin/env bash\nset -euo pipefail\nprintf "%s\\n" "'
            + log + '" >> "$CALL_LOG"\n' + body,
            encoding="utf-8", newline="\n"
        )

    def run_script(self, app, *, configured=True, scenario="", answer="y\n", fill_keys=True):
        script = (PROJECT / f"deploy-{app}.sh").read_text()
        if configured:
            for old, new in REPLACEMENTS.items():
                script = script.replace(old, new)
            if fill_keys:
                script = script.replace('REQUIRED_SECRET_KEYS=()', 'REQUIRED_SECRET_KEYS=("DATABASE_URL" "JWT_SECRET")')
        path = self.base / f"deploy-{app}.sh"
        path.write_text(script, encoding="utf-8", newline="\n")
        self.env.update(APP=app, SCENARIO=scenario)
        self.env["NEW_IMAGE"] = f"registry.example.invalid/sample-{app}@sha256:" + "a" * 64
        result = subprocess.run([BASH, "--noprofile", "--norc", path.as_posix()],
            cwd=self.base, env=self.env, input=answer.encode(), capture_output=True, timeout=40)
        result.stdout = result.stdout.decode("utf-8", errors="replace")
        result.stderr = result.stderr.decode("utf-8", errors="replace")
        calls = self.log.read_text() if self.log.exists() else ""
        return result, calls

    def test_placeholder_stops_before_any_external_command(self):
        for app in ("api", "web"):
            result, calls = self.run_script(app, configured=False)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("configure REGISTRY", result.stderr)
            self.assertEqual(calls, "")

    def test_cancel_pushes_but_never_connects_to_server(self):
        for app in ("api", "web"):
            if self.log.exists(): self.log.unlink()
            result, calls = self.run_script(app, answer="\n")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("Deployment cancelled", result.stdout)
            self.assertIn("docker buildx build", calls)
            self.assertNotIn("ssh\n", calls)

    def test_missing_secret_stops_before_image_change(self):
        result, calls = self.run_script("api", scenario="missing_secret")
        self.assertNotEqual(result.returncode, 0, "Missing Secret incorrectly permitted rollout")
        self.assertNotIn("sudo kubectl set image", calls)

    def test_wrong_secret_reference_stops_before_image_change(self):
        result, calls = self.run_script("api", scenario="wrong_ref")
        self.assertNotEqual(result.returncode, 0, "Wrong Secret reference incorrectly permitted rollout")
        self.assertNotIn("sudo kubectl set image", calls)

    def test_missing_key_stops_before_image_change(self):
        result, calls = self.run_script("api", scenario="missing_key")
        self.assertNotEqual(result.returncode, 0, "Missing required key incorrectly permitted rollout")
        self.assertNotIn("sudo kubectl set image", calls)
        self.assertIn("missing: DATABASE_URL", result.stderr)

    def test_valuefrom_secret_reference_is_supported(self):
        result, calls = self.run_script("api", scenario="key_ref")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("sudo kubectl set image", calls)

    def test_teaching_api_with_no_required_keys_can_release(self):
        result, calls = self.run_script("api", fill_keys=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("sudo kubectl set image", calls)

    def test_api_redirect_does_not_count_as_healthy(self):
        result, calls = self.run_script("api", scenario="public_redirect")
        self.assertNotEqual(result.returncode, 0, "Public redirect incorrectly reported healthy")
        self.assertNotIn("Release complete", result.stdout)

    def test_approved_releases_verify_live_image_and_health(self):
        for app in ("api", "web"):
            if self.log.exists(): self.log.unlink()
            result, calls = self.run_script(app)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("Release complete", result.stdout)
            self.assertIn("sudo kubectl set image", calls)
            self.assertIn("sudo kubectl rollout status", calls)
            if app == "api":
                self.assertIn("sudo kubectl get secret sample-runtime", calls)
                self.assertIn("envFrom", calls)
                self.assertIn("Runtime Secret preflight: PASS", result.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=2)
