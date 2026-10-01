// Regression tests for the Boot Guard row parser.
//
// The Boot Guard tab shipped in v2.1.6 rendered an empty list even though the
// engine emitted 26 perfectly good rows. Three defects stacked up in the old
// regex: it was anchored with ^BOOTGUARD while Write-Log prefixes every line
// with "[timestamp] ", it matched lowercase true/false while PowerShell emits
// True/False, and it used a fixed ([^|]+) group for the Id even though the Id
// itself contains pipes ("reg|HKCU|<value>") - which shifted every later field
// by a variable amount.
//
// These tests lock in the current contract. Note that testing this in PowerShell
// is not equivalent: -match is case-insensitive by default, which hides the
// casing bug entirely.

import { test } from "node:test";
import assert from "node:assert/strict";
import { parseBootGuardRow } from "./backend.js";

const ts = "[2026-10-01 21:16:46]";

test("parses a registry row whose Id contains pipes", () => {
  const line =
    `${ts} BOOTGUARD|reg|HKCU|loopMIDI|REGISTRY|loopMIDI|` +
    `"C:\\Program Files (x86)\\Tobias Erichsen\\loopMIDI\\loopMIDI.exe"|True|low|20|True|HKCU`;

  const row = parseBootGuardRow(line);
  assert.ok(row, "row must parse");
  assert.equal(row.kind, "REGISTRY");
  assert.equal(row.name, "loopMIDI");
  assert.equal(row.id, "reg|HKCU|loopMIDI");
  assert.equal(row.scope, "HKCU");
  assert.equal(row.command, '"C:\\Program Files (x86)\\Tobias Erichsen\\loopMIDI\\loopMIDI.exe"');
  assert.equal(row.impact, "low");
  assert.equal(row.ram, 20);
  assert.equal(row.safe, true);
  assert.equal(row.enabled, true);
});

test("tolerates the leading [timestamp] Write-Log adds to every line", () => {
  const body = "BOOTGUARD|svc|WinDefend|SERVICE|WinDefend|Microsoft Defender Antivirus Service|True|low|20|True|SERVICE";
  assert.ok(parseBootGuardRow(`${ts} ${body}`), "timestamp prefix must not block parsing");
  assert.ok(parseBootGuardRow(body), "bare row must parse too");
});

test("accepts PowerShell's capitalised True/False", () => {
  const row = parseBootGuardRow(
    `${ts} BOOTGUARD|svc|Bonjour Service|SERVICE|Bonjour Service|Bonjour Service|False|medium|150|False|SERVICE`
  );
  assert.ok(row, "capitalised booleans must parse");
  assert.equal(row.enabled, false);
  assert.equal(row.safe, false);
  assert.equal(row.impact, "medium");
  assert.equal(row.ram, 150);
});

test("keeps the task path in the Id (the 'task' prefix must not be eaten)", () => {
  const row = parseBootGuardRow(
    `${ts} BOOTGUARD|task|\\HP\\HP Print Scan Doctor\\Printer Health Monitor Logon|TASK|` +
      `Printer Health Monitor Logon|\\HP\\HP Print Scan Doctor\\Printer Health Monitor Logon|True|medium|120|False|TASK`
  );
  assert.ok(row, "task row must parse");
  assert.equal(row.kind, "TASK");
  assert.equal(row.name, "Printer Health Monitor Logon");
  assert.equal(row.id, "task|\\HP\\HP Print Scan Doctor\\Printer Health Monitor Logon");
  assert.equal(row.command, "\\HP\\HP Print Scan Doctor\\Printer Health Monitor Logon");
});

test("preserves pipes inside the Command field", () => {
  const row = parseBootGuardRow(
    `${ts} BOOTGUARD|reg|HKLM|SomeApp|REGISTRY|SomeApp|C:\\Program Files\\App\\app.exe --flag=a|b|True|high|500|False|HKLM`
  );
  assert.ok(row, "row must parse");
  assert.equal(row.command, "C:\\Program Files\\App\\app.exe --flag=a|b");
  assert.equal(row.name, "SomeApp");
  assert.equal(row.id, "reg|HKLM|SomeApp");
});

test("handles a CRLF-terminated final line", () => {
  const row = parseBootGuardRow(
    `${ts} BOOTGUARD|svc|WSLService|SERVICE|WSLService|WSL Service|True|high|500|False|SERVICE\r`
  );
  assert.ok(row, "CRLF row must parse");
  assert.equal(row.scope, "SERVICE", "trailing CR must not leak into scope");
  assert.equal(row.ram, 500);
});

test("folder rows parse", () => {
  const row = parseBootGuardRow(
    `${ts} BOOTGUARD|file|USERFOLDER|C:\\Users\\me\\AppData\\...\\Startup\\Thing.lnk|FOLDER|Thing.lnk|C:\\Users\\me\\AppData\\...\\Startup\\Thing.lnk|True|low|0|False|USERFOLDER`
  );
  assert.ok(row, "folder row must parse");
  assert.equal(row.kind, "FOLDER");
  assert.equal(row.id, "file|USERFOLDER|C:\\Users\\me\\AppData\\...\\Startup\\Thing.lnk");
  assert.equal(row.scope, "USERFOLDER");
});

test("rejects junk without throwing", () => {
  assert.equal(parseBootGuardRow(`${ts} === BOOT GUARD LIST COMPLETE ===`), null);
  assert.equal(parseBootGuardRow(`${ts} [dry-run] Read-only preview (non-admin).`), null);
  assert.equal(parseBootGuardRow(""), null);
  assert.equal(parseBootGuardRow(`${ts} BOOTGUARD|too|few|fields`), null);
});

test("rejects rows with an unparseable impact or ram value", () => {
  assert.equal(
    parseBootGuardRow(`${ts} BOOTGUARD|svc|X|SERVICE|X|X|True|enormous|150|False|SERVICE`),
    null,
    "unknown impact level must be rejected"
  );
  assert.equal(
    parseBootGuardRow(`${ts} BOOTGUARD|svc|X|SERVICE|X|X|True|medium|many|False|SERVICE`),
    null,
    "non-numeric ram must be rejected"
  );
});

test("every parsed Id has a prefix Set-BootGuardItem understands", () => {
  const rows = [
    `${ts} BOOTGUARD|reg|HKCU|loopMIDI|REGISTRY|loopMIDI|"C:\\a\\b.exe"|True|low|20|True|HKCU`,
    `${ts} BOOTGUARD|task|\\Vendor\\Updater|TASK|Updater|\\Vendor\\Updater|True|medium|100|False|TASK`,
    `${ts} BOOTGUARD|svc|Bonjour|SERVICE|Bonjour|Bonjour|True|medium|150|False|SERVICE`,
  ].map(parseBootGuardRow);

  const prefixes = rows.map((r) => r.id.split("|")[0]);
  assert.deepEqual(prefixes, ["reg", "task", "svc"]);
});
