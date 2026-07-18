import { spawn } from "node:child_process";
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..");

const CHECKS = {
  nodeSyntax: [
    "assets/renderer-inject.js",
    "scripts/injector.mjs",
    "scripts/preflight.mjs",
  ],
  json: [
    "assets/theme.json",
    "assets/style-palettes.json",
    "package.json",
  ],
  powershellGlob: "scripts/*.ps1",
  payload: true,
};

const results = [];
let overallPass = true;

function record(name, pass, detail) {
  results.push({ name, pass, detail });
  if (!pass) overallPass = false;
  const status = pass ? "PASS" : "FAIL";
  const suffix = detail ? ` — ${detail}` : "";
  console.log(`[${status}] ${name}${suffix}`);
}

function runCommand(file, args, options = {}) {
  return new Promise((resolve) => {
    const child = spawn(file, args, { cwd: root, shell: false, ...options });
    let stdout = "";
    let stderr = "";
    child.stdout?.on("data", (chunk) => { stdout += chunk.toString(); });
    child.stderr?.on("data", (chunk) => { stderr += chunk.toString(); });
    child.on("error", (error) => resolve({ code: -1, stdout, stderr: stderr + error.message }));
    child.on("close", (code) => resolve({ code: code ?? -1, stdout, stderr }));
  });
}

async function checkNodeSyntax() {
  for (const relative of CHECKS.nodeSyntax) {
    const target = path.join(root, relative);
    const { code, stderr } = await runCommand(process.execPath, ["--check", target]);
    record(`node --check ${relative}`, code === 0, code === 0 ? "" : stderr.trim().split("\n").pop());
  }
}

async function checkJson() {
  for (const relative of CHECKS.json) {
    const target = path.join(root, relative);
    try {
      JSON.parse(await fs.readFile(target, "utf8"));
      record(`JSON.parse ${relative}`, true, "");
    } catch (error) {
      record(`JSON.parse ${relative}`, false, error.message);
    }
  }
}

async function checkPowerShell() {
  const scriptsDir = path.join(root, "scripts");
  const entries = await fs.readdir(scriptsDir);
  const ps1 = entries.filter((name) => name.toLowerCase().endsWith(".ps1")).sort();
  if (!ps1.length) {
    record("powershell parse", true, "no *.ps1 files");
    return;
  }
  const inline = `
    $ErrorActionPreference = 'Stop';
    $failures = @();
    foreach ($file in @(${ps1.map((name) => `'${path.join(scriptsDir, name).replace(/\\/g, "\\\\").replace(/'/g, "''")}'`).join(", ")})) {
      $errors = $null;
      $tokens = $null;
      [void][Management.Automation.Language.Parser]::ParseFile($file, [ref]$tokens, [ref]$errors);
      if ($errors -and $errors.Count -gt 0) {
        foreach ($err in $errors) { $failures += ($file + ': ' + $err.Message) }
      }
    }
    if ($failures.Count -gt 0) { $failures | ForEach-Object { Write-Output $_ }; exit 1 } else { exit 0 }
  `;
  const powershell = process.platform === "win32" ? "powershell.exe" : "pwsh";
  const { code, stdout, stderr } = await runCommand(powershell, ["-NoProfile", "-NonInteractive", "-Command", inline]);
  if (code === 0) {
    record(`powershell parse (${ps1.length} files)`, true, "");
  } else {
    const detail = (stdout || stderr).trim().split("\n").slice(0, 3).join(" | ");
    record(`powershell parse (${ps1.length} files)`, false, detail || `exit ${code}`);
  }
}

async function checkPayload() {
  if (!CHECKS.payload) return;
  const target = path.join(root, "scripts", "injector.mjs");
  const { code, stdout, stderr } = await runCommand(process.execPath, [target, "--check-payload"]);
  if (code !== 0) {
    record("injector --check-payload", false, (stderr || stdout).trim().split("\n").pop());
    return;
  }
  try {
    const parsed = JSON.parse(stdout);
    record("injector --check-payload", Boolean(parsed.pass), `version=${parsed.version} bytes=${parsed.payloadBytes}`);
  } catch (error) {
    record("injector --check-payload", false, `unparsable output: ${error.message}`);
  }
}

async function main() {
  const started = Date.now();
  console.log(`preflight starting in ${root}`);
  await checkNodeSyntax();
  await checkJson();
  await checkPowerShell();
  await checkPayload();
  const elapsedMs = Date.now() - started;
  const summary = { pass: overallPass, elapsedMs, results };
  console.log(`\n${overallPass ? "PASS" : "FAIL"}: ${results.filter((r) => r.pass).length}/${results.length} checks in ${elapsedMs}ms`);
  await fs.mkdir(path.join(root, "artifacts"), { recursive: true }).catch(() => {});
  await fs.writeFile(path.join(root, "artifacts", "preflight.json"), JSON.stringify(summary, null, 2)).catch(() => {});
  process.exit(overallPass ? 0 : 1);
}

main().catch((error) => {
  console.error(`preflight crashed: ${error.stack || error.message}`);
  process.exit(2);
});
