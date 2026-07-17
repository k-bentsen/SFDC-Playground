#!/usr/bin/env node
// Resolves which Apex test classes cover the Apex changed in the delta
// package (`sf sgd:source:delta` output under delta_output/).
//
// Coverage is inferred by static reference matching, not real coverage
// data (that would mean running tests first, defeating the point of
// pre-selecting which ones to run). Matching works in three tiers, from
// most to least direct:
//   1. Naming convention: Foo.cls -> FooTest.cls / Foo_Test.cls
//   2. Direct reference: a test class's source mentions the changed
//      class/trigger by name (e.g. `new Foo()`)
//   3. Transitive reference: a test class references some other class
//      which itself (directly or transitively) references the changed
//      class - covers a shared helper/handler that's only exercised
//      indirectly through the class that uses it, and is never named in
//      the test file itself (e.g. a *Test class that only references the
//      class it's testing, which in turn instantiates a helper class).
//
// This is checked against every class currently on the branch (via a full
// checkout, not the delta output), since the covering test class is often
// unchanged by the PR.
//
// Exits non-zero if any changed non-test Apex resolves to zero tests, so a
// class with no coverage owner blocks the PR instead of silently deploying
// untested. Triggers are checked the same way, though most trigger
// coverage comes from DML in a test rather than a literal name reference -
// this heuristic won't catch that; name the trigger directly in a test
// (even in a comment) if it needs to be discoverable this way.

import { readdirSync, readFileSync, existsSync, appendFileSync } from 'node:fs';
import { join, basename } from 'node:path';

const DELTA_CLASSES_DIR = 'delta_output/force-app/main/default/classes';
const DELTA_TRIGGERS_DIR = 'delta_output/force-app/main/default/triggers';
const REPO_CLASSES_DIR = 'force-app/main/default/classes';

function listFiles(dir, ext) {
  if (!existsSync(dir)) return [];
  return readdirSync(dir, { recursive: true })
    .filter((f) => f.endsWith(ext))
    .map((f) => join(dir, f));
}

function writeOutput(tests) {
  // Space-separated, not comma-separated: current sf CLI versions read
  // --tests as one or more space-separated names (or repeated --tests
  // flags) - a comma-joined value gets treated as a single, nonexistent
  // test name, silently running zero tests.
  console.log(tests.length ? `Resolved tests: ${tests.join(' ')}` : 'No Apex changes in delta; no tests required.');
  const output = process.env.GITHUB_OUTPUT;
  if (output) appendFileSync(output, `tests=${tests.join(' ')}\n`);
}

function isTestName(name) {
  return /Test$/i.test(name) || /_Test$/i.test(name);
}

function isTestName(name) {
  return /Test$/i.test(name) || /_Test$/i.test(name);
}

const changedClassNames = listFiles(DELTA_CLASSES_DIR, '.cls').map((f) => basename(f, '.cls'));
const changedTriggerNames = listFiles(DELTA_TRIGGERS_DIR, '.trigger').map((f) => basename(f, '.trigger'));
const changedApexNames = [...changedClassNames, ...changedTriggerNames];

if (changedApexNames.length === 0) {
  writeOutput([]);
  process.exit(0);
}

// name -> source, for every class currently on the branch.
const sourceByName = new Map();
for (const file of listFiles(REPO_CLASSES_DIR, '.cls')) {
  sourceByName.set(basename(file, '.cls'), readFileSync(file, 'utf8'));
}
const allNames = [...sourceByName.keys()];
const testNames = allNames.filter(isTestName);

// Reference graph: name -> Set of other class names its source mentions
// as a whole word. This is what makes coverage detection transitive.
const referenceGraph = new Map();
for (const [name, source] of sourceByName) {
  const refs = new Set();
  for (const other of allNames) {
    if (other !== name && new RegExp(`\\b${other}\\b`).test(source)) refs.add(other);
  }
  referenceGraph.set(name, refs);
}

function testCovers(testName, target) {
  const visited = new Set([testName]);
  const stack = [...(referenceGraph.get(testName) ?? [])];
  while (stack.length) {
    const current = stack.pop();
    if (current === target) return true;
    if (visited.has(current)) continue;
    visited.add(current);
    for (const next of referenceGraph.get(current) ?? []) stack.push(next);
  }
  return false;
}

const resolvedTests = new Set();
const orphans = [];

for (const name of changedApexNames) {
  if (isTestName(name)) {
    // A changed file is itself a test class - run it directly.
    resolvedTests.add(name);
    continue;
  }

  let matched = false;
  for (const testName of testNames) {
    if (testName === `${name}Test` || testName === `${name}_Test` || testCovers(testName, name)) {
      resolvedTests.add(testName);
      matched = true;
    }
  }

  if (!matched) orphans.push(name);
}

if (orphans.length > 0) {
  console.error(
    `No test class found covering: ${orphans.join(', ')} ` +
      '(checked naming convention, direct references, and references through other classes). ' +
      'Add or rename a test class, or have an existing one reference this class - even transitively, ' +
      'through another class it exercises.'
  );
  process.exit(1);
}

writeOutput([...resolvedTests]);
