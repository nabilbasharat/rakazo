# Upstream updates with Cezar

Select `safe-upstream-update` as the workflow in a Cezar automation or task.
Configure the project base branch as `main` and run with a worktree. The task
must start at the current `origin/main`; it stops if the fork advanced before
preflight. Configure `origin` as the fork and `upstream` as the Horolog source
(currently `https://github.com/ujjwalredd/horolog.git`). Both need a `main`
branch and fetch access. Publishing also needs permission to push a task branch
and create a PR on the fork. Install the repository's Node and Python test
and build dependencies first (`npm run check` must be available).

The workflow fetches both branches, records their tips and compares them. If
upstream is already an ancestor of the fork it finishes without a PR. Otherwise
it merges the recorded upstream commit, asks Codex to resolve conflicts, checks
ancestry and a clean worktree, runs `npm run check`, and has Codex review the
result. Failed checks and review findings get at most two repair attempts.
Unresolved conflicts, failing verification, missing dependencies and blocked
reviews stop the run. The review is advisory, not proof that every customization
survived: inspect the diff and migration notes yourself.

Approval at the human gate pushes the task branch and opens a **draft PR** to
the task's base (`main`). It does not merge the PR or deploy. Rejecting or
letting the gate time out publishes nothing. Cezar must be able to pause for
human approval, so do not configure the automation to bypass the gate. Review
the PR, CI, migrations and deployment procedure separately. Repeated scheduled
runs can produce separate PRs while earlier updates remain unmerged; check for
existing PRs before approving publication.
