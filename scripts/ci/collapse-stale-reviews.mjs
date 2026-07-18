#!/usr/bin/env node
// forcedotcom/run-code-analyzer always creates a brand-new PR review every
// run - it has no built-in way to detect or update a previous one. Left
// alone, every push to a PR leaves another full summary review behind,
// piling up noise.
//
// Runs before that action, so it only ever sees reviews from earlier runs.
// Identifies "summary" reviews by author (github-actions[bot], same actor
// both that action and our own post-inline-comments.mjs use via
// secrets.GITHUB_TOKEN) plus having a non-empty top-level body - our own
// inline-comment reviews never set one, only individual line comments, so
// this only targets the summary review, not the per-violation ones.
//
// GitHub's API has no delete endpoint for a review's own body/top-level
// comment (only for individual review comments within one, and only
// dismissal - not deletion - for APPROVE/REQUEST_CHANGES reviews, neither
// of which applies here), only update. So "collapse" means overwriting the
// stale body with a short placeholder, not removing it outright.

const GITHUB_TOKEN = process.env.GITHUB_TOKEN;
const REPO = process.env.GITHUB_REPOSITORY;
const PR_NUMBER = process.env.PR_NUMBER;
const ACTOR_LOGIN = process.env.ACTOR_LOGIN || 'github-actions[bot]';

if (!GITHUB_TOKEN || !REPO || !PR_NUMBER) {
  console.log('Missing GITHUB_TOKEN, GITHUB_REPOSITORY, or PR_NUMBER - skipping.');
  process.exit(0);
}

const apiBase = `https://api.github.com/repos/${REPO}`;
const headers = {
  Authorization: `Bearer ${GITHUB_TOKEN}`,
  Accept: 'application/vnd.github+json',
  'Content-Type': 'application/json',
};

const listRes = await fetch(`${apiBase}/pulls/${PR_NUMBER}/reviews?per_page=100`, { headers });
if (!listRes.ok) {
  console.log(`Could not list existing reviews (${listRes.status}): ${await listRes.text()}`);
  process.exit(0);
}
const reviews = await listRes.json();

const stale = reviews.filter((r) => r.user?.login === ACTOR_LOGIN && r.body?.trim());

if (stale.length === 0) {
  console.log('No previous summary reviews to collapse.');
  process.exit(0);
}

for (const review of stale) {
  const res = await fetch(`${apiBase}/pulls/${PR_NUMBER}/reviews/${review.id}`, {
    method: 'PUT',
    headers,
    body: JSON.stringify({ body: '_Superseded by a newer Code Analyzer run - see below._' }),
  });
  if (res.ok) {
    console.log(`Collapsed stale review ${review.id}.`);
  } else {
    console.log(`Could not collapse review ${review.id} (${res.status}): ${await res.text()}`);
  }
}
