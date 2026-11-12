# Workflow: A WPT probe without --output writes into the shared WPT tree

**Date**: 2026-11-12
**Lesson**: Every direct `wpt_runner` run on a pool host passes `--output=<your mirror>/tmp/<name>`. The runner runs from the shared WPT tree, and its default output is `wpt-results/` under that working directory.

**Why**: The runner needs `cd ~/crane-work/main/tests/wpt` (the host's shared tree) or `--wpt-root`. Without `--output` it writes `wpt-results/` relative to its working directory. That puts journals, queues and wptreport files inside the tree every lane and every sweep share. The crane guard blocks `rm` under `tests/wpt/` outside `crane/` (never edit upstream WPT), so the lane cannot clean them up, and the integrator does not route around the guard either.

**What Happened**: Lane nav2 batch 10 ran three short probes of Crane tests with `crane-measure.sh run ... wpt_runner --verbose` from `$W`, with no `--output`. They left 11 files (84 KB) in server1 `~/crane-work/main/tests/wpt/wpt-results/`, each run overwriting the last. The red runner's crash record went with them. Nothing reads that directory, so it was harmless, but it was left for the user to remove.

**Fix**: Give every direct run `--output=$HOME/crane-work/<mirror>/tmp/probe-<name>`. A `crane-measure.sh sweep` takes its outdir as an argument and is already safe. Read results from the journal in that directory.

**Takeaway**: **A runner started from the shared WPT tree writes into it unless told otherwise. Always pass `--output` into your own mirror's tmp, because you will not be able to delete what lands in tests/wpt.**
