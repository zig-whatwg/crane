# Workflow: wpt_runner path arguments - files win over directories, and a directory has no trailing slash

**Date**: 2026-11-19
**Lesson**: Given both file and directory arguments, wpt_runner runs only the files; and a directory argument written with a trailing slash ("sanitizer-api/") discovers nothing from the manifest, while "sanitizer-api" finds its 47 files.

**Why**: Discovery treats explicit files as the whole selection when any is given, and matches directory arguments against manifest paths without normalising a trailing "/". Neither is reported: the run simply covers fewer files, and an A/B over it reports "0 losses" for files it never ran.

**What Happened**: Lane maj2's first targeted A/B passed 3 files and 8 directories in one invocation (some with "dir/"); both sides journalled 5 files, and the comparison looked clean. `--discover-only` showed "Found 1 test files" for `sanitizer-api/ url/x.any.js` and 47 for `sanitizer-api`.

**Fix**: Run files and directories as two invocations (lane maj2's .maj2/ab.sh splits its arguments by extension and runs each group into its own output directory), strip trailing slashes, and check each side's journal line count against the expected file count before reading the comparison.

**Takeaway**: **Never mix file and directory arguments in one wpt_runner run, write directories without a trailing slash, and count the journalled files before trusting an A/B's "0 losses".**
