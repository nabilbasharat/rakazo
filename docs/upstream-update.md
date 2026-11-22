# Upstream updates with Cezar

Select `safe-upstream-update` for a task in a dedicated worktree based on the
current `origin/main`. The workflow and its matching script must both be
committed and integrated into that base before starting a task: the cockpit can
load a local workflow while the task worktree uses committed base files.
Configure `origin` as the Rakazo fork and `upstream` as
the intended Rakazo upstream. Check the remote URLs before running: the script
cannot establish whether a configured remote is trustworthy. Both need a
`main` branch and fetch access. Publishing requires permission to push a task
branch and create a pull request on the fork.

Install a Node version supported by `package.json` and npm. The workflow
installs workspace dependencies using the specified pnpm version, then runs
lint, Turbo checks, the Node script tests and Vitest sequentially; repository CI
provides additional build, integration and end-to-end coverage. Missing dependencies or checks that need unavailable services can stop
the run. Desktop Electron end-to-end tests belong in CI, not routine local runs.

The workflow records both fetched tips and merges the upstream commit if it is
not already included. It resolves conflicts with Codex, verifies ancestry and
the worktree, runs checks, and requests an independent review. Failed checks or
review findings get at most two repair attempts. Its Git verification script is
copied from the original task commit before merging, so an upstream change to
the script does not replace the checks during this run.

Run only in an isolated environment with no production credentials or sensitive
files: merged code and dependency scripts can execute before approval. Human
approval permits pushing the task branch and opening a draft PR; it does not
merge or deploy. After approval the workflow checks that the fork's main branch
has not advanced; if it has, start a new run. The branch could still advance
between that check and PR creation, so review the PR's current base and CI
before merging. Review migrations and fork customizations explicitly. Scheduled
runs can create separate PRs while previous updates remain unmerged.

The Git safety steps assume `origin/main` and `upstream/main`; the checks and
review requirements are specific to this repository. Reusing the workflow for
another repository requires choosing its remotes, branches, dependencies and
validation commands; there is no universally correct test command.

Validation requires a supported Node version, npm, Python, taskset, and a working
systemd user manager with CPU and memory cgroup controllers. Before merging,
the workflow checks these prerequisites. After the merge it uses the pinned
pnpm version and installs dependencies from the lockfile; an installation error
stops the run without asking an agent to repair application code. Installation
and each validation sequence run in a user service limited to two CPUs, 3000
MiB of memory and no swap, with one Turbo task and one test worker at a time.
Timeouts, missing executables and processes killed by the resource limit stop
the run. Check failures may still need human diagnosis; not every external
failure can be distinguished from a test failure by its exit status.

These service limits cover the installation and validation command trees only,
not Cezar, its agents, the merge, or other processes on the machine. They do not
establish a limit for the entire automation. Use an externally limited runner
if a hard limit for the complete automation is required. A workflow definition
is fixed for a running task: changes to it take effect on the next run.
