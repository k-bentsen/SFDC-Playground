#!/usr/bin/env node
// Reads .github/ci-config.json and emits the entry for the given branch as
// GitHub Actions job outputs, so downstream jobs can gate on it with
// `if: fromJSON(needs.resolve-config.outputs.config).checks.<name>`.

import { readFileSync, appendFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const branch = process.argv[2];

if (!branch) {
  console.error('Usage: resolve-config.mjs <branch-name>');
  process.exit(1);
}

const configPath = join(__dirname, '..', '..', '.github', 'ci-config.json');
const config = JSON.parse(readFileSync(configPath, 'utf8'));
const entry = config[branch];

if (!entry) {
  console.error(
    `No .github/ci-config.json entry for branch "${branch}". ` +
      'Add one before CI can run against it.'
  );
  process.exit(1);
}

const lines = [
  `config=${JSON.stringify(entry)}`,
  `org=${entry.org}`,
  `testLevel=${entry.testLevel}`,
];

console.log(`Resolved config for "${branch}":`, entry);

const output = process.env.GITHUB_OUTPUT;
if (output) {
  appendFileSync(output, lines.map((l) => `${l}\n`).join(''));
}
