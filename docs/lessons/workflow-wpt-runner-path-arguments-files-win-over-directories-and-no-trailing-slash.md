# Workflow: wpt_runner path arguments - files win over directories

**Date**: 2026-11-19
**Status** (2026-11-19, corrected the same day by lane maj2): the first version of this lesson also said that a directory written with a trailing slash ("sanitizer-api/") discovers nothing. That is wrong. `--discover-only` finds 47 files for both "sanitizer-api/" and "sanitizer-api", 17 for "html/webappapis/timers/" and "html/webappapis/timers", and 64 for "sanitizer-api/ html/webappapis/timers/". Only mixing files and directories loses files. The file name keeps "no-trailing-slash" so links to it keep working.
**Lesson**: Given both file and directory arguments, wpt_runner runs only the files.

**Why**: Discovery treats explicit files as the whole selection when any is given. Nothing reports it: the run simply covers fewer files, and an A/B over it reports "0 losses" for files it never ran.

**What Happened**: Lane maj2's first targeted A/B passed 3 files and 8 directories in one invocation, and both sides journalled 5 files, so the comparison looked clean. `--discover-only` showed "Found 1 test files" for `sanitizer-api url/url-setters-a-area.window.js`, and 47 for `sanitizer-api` alone (with or without a trailing slash).

**Fix**: Run files and directories as two invocations. Lane maj2's .maj2/ab.sh splits its arguments by extension and runs each group into its own output directory. Then check each side's journal line count against the expected file count before reading the comparison.

**Takeaway**: **Never mix file and directory arguments in one wpt_runner run, and count the journalled files before trusting an A/B's "0 losses".**
