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
// Only Active flows are required to have a Flow Test - draft/in-progress flows
// are exempt so WIP edits don't get blocked on test authoring.

import {
  readdirSync,
  readFileSync,
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
  console.log('No Flow changes in delta.');
  process.exit(0);
}

const allFlowTests = listFiles(REPO_FLOWTESTS_DIR, '.flowtest-meta.xml');
const orphans = [];
let included = 0;

for (const flowFile of changedFlows) {
  const flowName = basename(flowFile, '.flow-meta.xml');
  const xml = readFileSync(flowFile, 'utf8');
  const isActive = /<status>Active<\/status>/.test(xml);

  const matches = allFlowTests.filter((f) => basename(f).startsWith(`${flowName}.`));

  if (matches.length === 0) {
    if (isActive) orphans.push(flowName);
    continue;
  }

  for (const match of matches) {
    const dest = join(DELTA_FLOWTESTS_DIR, basename(match));
    mkdirSync(dirname(dest), { recursive: true });
    copyFileSync(match, dest);
    included += 1;
  }
}

if (orphans.length > 0) {
  console.error(
    `Active flow(s) with no Flow Test found: ${orphans.join(', ')}. ` +
      'Add a Flow Test in Flow Builder before this can be validated.'
  );
  process.exit(1);
}

console.log(`Included ${included} Flow Test file(s) in the delta package.`);
