#!/usr/bin/env node
// Resolves which Apex test classes cover the Apex changed in the delta package
// (`sf sgd:source:delta` output under .delta/). Matching is naming-convention
// first (Foo.cls -> FooTest.cls / Foo_Test.cls), then falls back to grepping
// every test class in the repo for a reference to the changed class/trigger
// name, so shared utility classes and trigger handlers still get covered
// without requiring a strict naming convention everywhere.
//
// Exits non-zero if any changed non-test Apex resolves to zero tests, so a
// class with no coverage owner blocks the PR instead of silently deploying
// untested.

import { readdirSync, readFileSync, existsSync, appendFileSync } from 'node:fs';
import { join, basename } from 'node:path';

const DELTA_CLASSES_DIR = '.delta/force-app/main/default/classes';
const DELTA_TRIGGERS_DIR = '.delta/force-app/main/default/triggers';
const REPO_CLASSES_DIR = 'force-app/main/default/classes';

function listFiles(dir, ext) {
  if (!existsSync(dir)) return [];
  return readdirSync(dir, { recursive: true })
    .filter((f) => f.endsWith(ext))
    .map((f) => join(dir, f));
}

function writeOutput(tests) {
  console.log(tests.length ? `Resolved tests: ${tests.join(',')}` : 'No Apex changes in delta; no tests required.');
  const output = process.env.GITHUB_OUTPUT;
  if (output) appendFileSync(output, `tests=${tests.join(',')}\n`);
}

const changedClassNames = listFiles(DELTA_CLASSES_DIR, '.cls').map((f) => basename(f, '.cls'));
const changedTriggerNames = listFiles(DELTA_TRIGGERS_DIR, '.trigger').map((f) => basename(f, '.trigger'));
const changedApexNames = [...changedClassNames, ...changedTriggerNames];

if (changedApexNames.length === 0) {
  writeOutput([]);
  process.exit(0);
}

const allTestFiles = listFiles(REPO_CLASSES_DIR, '.cls').filter((f) => {
  const name = basename(f, '.cls');
  return /Test$/i.test(name) || /_Test$/i.test(name);
});

const resolvedTests = new Set();
const orphans = [];

for (const name of changedApexNames) {
  if (/Test$/i.test(name) || /_Test$/i.test(name)) {
    // A changed file is itself a test class - run it directly.
    resolvedTests.add(name);
    continue;
  }

  let matched = false;
  for (const testFile of allTestFiles) {
    const testName = basename(testFile, '.cls');
    const namingMatch = testName === `${name}Test` || testName === `${name}_Test`;
    const contentMatch = !namingMatch && new RegExp(`\\b${name}\\b`).test(readFileSync(testFile, 'utf8'));
    if (namingMatch || contentMatch) {
      resolvedTests.add(testName);
      matched = true;
    }
  }

  if (!matched) orphans.push(name);
}

if (orphans.length > 0) {
  console.error(
    `No test class found covering: ${orphans.join(', ')}. ` +
      'Add or rename a test class so it is discoverable by naming convention ' +
      '(FooTest.cls / Foo_Test.cls) or by referencing the class/trigger name in its body.'
  );
  process.exit(1);
}

writeOutput([...resolvedTests]);
