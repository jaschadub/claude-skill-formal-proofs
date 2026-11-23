// Copyright (c) 2026 Jascha Wanger (jascha.me). MIT license; see LICENSE.
// Needs Java and tla2tools.jar: set TLA2TOOLS, or run `sh skills/tla-check/test.sh` once to download it.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { test } from "node:test";
import { readSany } from "../frontends/spec.ts";

const launcher = path.join(import.meta.dirname, "../statechart");
const jar = path.resolve(
  process.env.TLA2TOOLS ??
    path.join(process.env.XDG_CACHE_HOME ?? path.join(os.homedir(), ".cache"), "tla-check/tla2tools-1.7.4.jar"),
);

// BankAccepts sets paid and also lists it as UNCHANGED, so it never makes a step and the rule cannot break.
const VAC = `---- MODULE Vac ----
EXTENDS Naturals
VARIABLES sent, paid
Init == sent = 0 /\\ paid = FALSE
YouPressPay == sent < 2 /\\ sent' = sent + 1 /\\ UNCHANGED paid
BankAccepts == sent > 0 /\\ paid' = TRUE /\\ UNCHANGED <<sent, paid>>
Done == sent = 2 /\\ UNCHANGED <<sent, paid>>
Next == YouPressPay \\/ BankAccepts \\/ Done
Spec == Init /\\ [][Next]_<<sent, paid>>
NeverPaidTwice == ~(paid /\\ sent > 1)
====
`;

test("a rule that holds only because an action never ran says so above the verdict, with relative tool paths", () => {
  assert.ok(fs.existsSync(jar), `no tla2tools.jar at ${jar}`);
  const dir = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), "statechart-test-")));
  try {
    fs.mkdirSync(path.join(dir, "model"));
    fs.writeFileSync(path.join(dir, "model/Vac.tla"), VAC);
    fs.writeFileSync(path.join(dir, "model/Vac.cfg"), "SPECIFICATION Spec\nINVARIANT NeverPaidTwice\n");
    fs.mkdirSync(path.join(dir, "jdk"));
    fs.writeFileSync(path.join(dir, "jdk/java"), '#!/bin/sh\nexec java "$@"\n', { mode: 0o755 });
    const r = spawnSync("sh", [launcher, "model/Vac.tla", "--config", "model/Vac.cfg", "--out", "out"], {
      cwd: dir,
      encoding: "utf8",
      env: { ...process.env, TLA2TOOLS: path.relative(dir, jar), JAVA: "./jdk/java" },
    });
    assert.equal(r.status, 0, r.stderr);
    const report = fs.readFileSync(path.join(dir, "out/report.md"), "utf8");
    const verdict = report.indexOf("\n## Rules that hold\nNeverPaidTwice, NoDeadlock");
    assert.notEqual(verdict, -1, report);
    for (const line of [
      "The variable paid was changed while it is specified as UNCHANGED",
      "## Actions that never ran\nBankAccepts.",
    ]) {
      const at = report.indexOf(line);
      assert.ok(at !== -1 && at < verdict, `${line}\n${report}`);
    }
    assert.doesNotMatch(report, /UseParallelGC/);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test("with java on PATH and the jar that tla-check keeps, it does not call mise", () => {
  assert.ok(fs.existsSync(jar), `no tla2tools.jar at ${jar}`);
  const dir = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), "statechart-test-")));
  try {
    fs.writeFileSync(path.join(dir, "Vac.tla"), VAC);
    fs.writeFileSync(path.join(dir, "Vac.cfg"), "SPECIFICATION Spec\nINVARIANT NeverPaidTwice\n");
    fs.mkdirSync(path.join(dir, "cache/tla-check"), { recursive: true });
    fs.symlinkSync(jar, path.join(dir, "cache/tla-check/tla2tools-1.7.4.jar"));
    fs.mkdirSync(path.join(dir, "bin"));
    fs.writeFileSync(path.join(dir, "bin/mise"), '#!/bin/sh\necho "mise was called" >&2\nexit 99\n', { mode: 0o755 });
    const env: NodeJS.ProcessEnv = {
      ...process.env,
      XDG_CACHE_HOME: path.join(dir, "cache"),
      PATH: `${path.join(dir, "bin")}${path.delimiter}${process.env.PATH}`,
    };
    delete env.TLA2TOOLS;
    delete env.JAVA;
    const r = spawnSync("sh", [launcher, "Vac.tla", "--config", "Vac.cfg", "--out", "out"], { cwd: dir, encoding: "utf8", env });
    assert.equal(r.status, 0, r.stderr);
    assert.ok(fs.existsSync(path.join(dir, "out/report.md")));
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

// From cursor/plugins pull request 1222. SANY wraps comments in CDATA, and a comment can hold <<1, 2>>.
test("a comment with < and > in it does not hide the variables after it", () => {
  const sany = readSany(`<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<modules>
  <RootModule>M</RootModule>
  <context>
    <entry>
      <UID>1</UID>
      <ModuleNode>
        <uniquename>M</uniquename>
        <pre-comments><![CDATA[(* x > y, then <<1, 2>> and a < b. *)]]></pre-comments>
        <OpDeclNodeRef><UID>2</UID></OpDeclNodeRef>
      </ModuleNode>
    </entry>
    <entry>
      <UID>2</UID>
      <OpDeclNode>
        <uniquename>x</uniquename>
        <kind>3</kind>
      </OpDeclNode>
    </entry>
  </context>
</modules>`);
  assert.deepEqual(sany.variables, ["x"]);
});
