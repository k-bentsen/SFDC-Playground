#!/usr/bin/env node
// For every Flow changed in the delta package, pulls the matching Flow Test
// metadata (force-app/main/default/flowTests/<FlowApiName>.<TestName>.flowtest-meta.xml)
// into the delta package so it's included in the deploy/validate call.
//
// Salesforce runs Flow Tests automatically as part of a deploy/validate
// operation whenever FlowTest metadata for an included Flow is present in the
// package - there is no separate "run flow tests" invocation. NOTE: the exact
// mechanics/file layout for Flow Testing have moved across recent Salesforce
// releases; confirm this still matches the current release notes for your org's
// API version before relying on it.
//
// This is opt-in, not a coverage gate: if none of the changed flows have a
// matching Flow Test, that's not a failure - it's simply skipped. Pass/fail
// only comes into play once a Flow Test actually gets included, at which
// point the platform runs it as part of deploy/validate and that step's own
// success/failure reflects the result.

import {
  readdirSync,
  existsSync,
  mkdirSync,
  copyFileSync,
} from 'node:fs';
import { join, basename, dirname } from 'node:path';

const DELTA_FLOWS_DIR = 'delta_output/force-app/main/default/flows';
const REPO_FLOWTESTS_DIR = 'force-app/main/default/flowTests';
const DELTA_FLOWTESTS_DIR = 'delta_output/force-app/main/default/flowTests';

function listFiles(dir, suffix) {
  if (!existsSync(dir)) return [];
  return readdirSync(dir, { recursive: true })
    .filter((f) => f.endsWith(suffix))
    .map((f) => join(dir, f));
}

const changedFlows = listFiles(DELTA_FLOWS_DIR, '.flow-meta.xml');

if (changedFlows.length === 0) {
  console.log('No Flow changes in delta - skipping.');
  process.exit(0);
}

const allFlowTests = listFiles(REPO_FLOWTESTS_DIR, '.flowtest-meta.xml');
let included = 0;

for (const flowFile of changedFlows) {
  const flowName = basename(flowFile, '.flow-meta.xml');
  const matches = allFlowTests.filter((f) => basename(f).startsWith(`${flowName}.`));

  for (const match of matches) {
    const dest = join(DELTA_FLOWTESTS_DIR, basename(match));
    mkdirSync(dirname(dest), { recursive: true });
    copyFileSync(match, dest);
    included += 1;
  }
}

if (included === 0) {
  console.log('No Flow Tests found for the changed flow(s) - skipping.');
} else {
  console.log(`Included ${included} Flow Test file(s) in the delta package.`);
}
