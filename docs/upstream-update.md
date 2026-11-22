# Upstream updates with Cezar

Select `safe-upstream-update` for a task in a dedicated worktree based on the
current `origin/main`. Commit and integrate the matching workflow and script
into that base before starting a task: the cockpit can load a local workflow
while the task worktree uses committed base files. Configure `origin` as the
Rakazo fork and `upstream` as the intended Rakazo upstream. Check the remote
URLs before running; the script cannot establish whether a remote is trustworthy.
Both need a `main` branch and fetch access. Publishing requires permission to
push a task branch and create a pull request on the fork.

The workflow records both fetched tips and merges the upstream commit if it is
not already included. It resolves conflicts with Codex, verifies ancestry and a
clean worktree, and requests an independent review of fork customizations,
migrations and security. Review findings get at most two repair attempts. The
Git verification script is copied from the starting commit before merging so
upstream cannot replace it during the run.

The workflow does not install dependencies or run local tests. After human
approval it checks that the fork's main branch has not advanced, pushes the
task branch and opens a draft PR. CI and review are still required: verify that
PR workflows run in the fork, inspect their results and run any additional
checks needed for the changes before merging. A clean merge and ancestry checks
do not establish that fork customizations still work. The base can advance
between the final check and PR creation; review the PR's current base as well.
No deployment or PR merge is performed by this workflow.

Run in an isolated environment without production credentials or sensitive
files. Conflict resolution and review are agent actions and can run commands;
merging upstream is not a security boundary. Scheduled runs can create separate
PRs while previous updates remain unmerged. A workflow definition is fixed for
a running task; changes to it take effect on the next run.
