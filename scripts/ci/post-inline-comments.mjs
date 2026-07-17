#!/usr/bin/env node
// Posts inline PR review comments for Salesforce Code Analyzer violations
// at or above a configured severity threshold, reading the JSON report
// produced by forcedotcom/run-code-analyzer (RESULTS_FILE).
//
// Best-effort: a violation's line has to fall within this PR's diff for
// GitHub to accept a line-anchored review comment on it. Static analysis
// can flag pre-existing lines in a changed file that the PR never touched,
// which GitHub will reject (422). This script tries to post everything in
// one review call first (fast path), and if that's rejected, falls back to
// posting comments one at a time so a single bad line doesn't drop every
// other comment - failures are logged, not silently swallowed, but don't
// fail the job on their own (the severity gate step handles pass/fail).
//
// NOTE: the exact shape of Code Analyzer's JSON output and GitHub's line-
// comment API behavior for out-of-diff lines are both worth re-verifying
// against a real run - every API failure is logged with its response body
// below, so check the job log first if comments aren't showing up.

import { readFileSync, existsSync } from 'node:fs';

const RESULTS_FILE = process.env.RESULTS_FILE || 'sfca_results.json';
const MIN_SEVERITY = process.env.MIN_SEVERITY;
const GITHUB_TOKEN = process.env.GITHUB_TOKEN;
const REPO = process.env.GITHUB_REPOSITORY;
const PR_NUMBER = process.env.PR_NUMBER;
const HEAD_SHA = process.env.HEAD_SHA;

// 1 = most severe. "medium" covers medium/high/critical (severity <= 3);
// "critical" covers only critical (severity <= 1).
const SEVERITY_RANK = { critical: 1, high: 2, medium: 3, low: 4, info: 5 };

if (!MIN_SEVERITY || !(MIN_SEVERITY in SEVERITY_RANK)) {
  console.error(
    `MIN_SEVERITY must be one of: ${Object.keys(SEVERITY_RANK).join(', ')}. Got: "${MIN_SEVERITY}"`
  );
  process.exit(1);
}
const threshold = SEVERITY_RANK[MIN_SEVERITY];

if (!existsSync(RESULTS_FILE)) {
  console.log(`No ${RESULTS_FILE} found - nothing to comment on.`);
  process.exit(0);
}

const report = JSON.parse(readFileSync(RESULTS_FILE, 'utf8'));
const violations = report.violations ?? [];

function toRepoPath(file) {
  const workspace = process.env.GITHUB_WORKSPACE;
  let p = file;
  if (workspace && p.startsWith(workspace)) {
    p = p.slice(workspace.length).replace(/^\/+/, '');
  }
  if (p.startsWith('delta_output/')) {
    p = p.slice('delta_output/'.length);
  }
  return p;
}

const SEVERITY_LABEL = { 1: 'Critical', 2: 'High', 3: 'Moderate', 4: 'Low', 5: 'Info' };

const comments = violations
  .filter((v) => v.severity <= threshold)
  .map((v) => {
    const loc = v.locations[v.primaryLocationIndex ?? 0];
    return {
      path: toRepoPath(loc.file),
      line: loc.startLine,
      side: 'RIGHT',
      body: `**${SEVERITY_LABEL[v.severity] ?? v.severity} · ${v.rule}** (${v.engine})\n\n${v.message}`,
    };
  });

if (comments.length === 0) {
  console.log(`No violations at or above severity "${MIN_SEVERITY}" - no comments to post.`);
  process.exit(0);
}

if (!GITHUB_TOKEN || !REPO || !PR_NUMBER || !HEAD_SHA) {
  console.error('Missing one of GITHUB_TOKEN, GITHUB_REPOSITORY, PR_NUMBER, HEAD_SHA - cannot post comments.');
  process.exit(0);
}

const apiBase = `https://api.github.com/repos/${REPO}`;
const headers = {
  Authorization: `Bearer ${GITHUB_TOKEN}`,
  Accept: 'application/vnd.github+json',
  'Content-Type': 'application/json',
};

async function postReview() {
  const res = await fetch(`${apiBase}/pulls/${PR_NUMBER}/reviews`, {
    method: 'POST',
    headers,
    body: JSON.stringify({ commit_id: HEAD_SHA, event: 'COMMENT', comments }),
  });
  if (res.ok) return true;
  console.log(`Batch review comment failed (${res.status}): ${await res.text()}`);
  return false;
}

async function postCommentsIndividually() {
  let posted = 0;
  let skipped = 0;
  for (const comment of comments) {
    const res = await fetch(`${apiBase}/pulls/${PR_NUMBER}/comments`, {
      method: 'POST',
      headers,
      body: JSON.stringify({ commit_id: HEAD_SHA, ...comment }),
    });
    if (res.ok) {
      posted++;
    } else {
      skipped++;
      console.log(
        `Skipped comment on ${comment.path}:${comment.line} (${res.status}): ` +
          `likely outside this PR's diff. ${await res.text()}`
      );
    }
  }
  console.log(`Posted ${posted} inline comment(s), skipped ${skipped}.`);
}

const batchSucceeded = await postReview();
if (batchSucceeded) {
  console.log(`Posted ${comments.length} inline comment(s) as a single review.`);
} else {
  console.log('Falling back to posting comments individually...');
  await postCommentsIndividually();
}
