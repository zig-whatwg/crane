# Testing: Read JSONL with its record delimiter

**Date**: 2026-10-06
**Lesson**: Split JSONL on LF, preserving other Unicode line separators inside JSON strings.

**Why**: General-purpose line splitting can recognize more separators than a format defines. JSON permits Unicode separators inside strings, including test names containing unusual parser input.

**What Happened**: A scratch comparison used Python's splitlines() on WPT subtest streams and reported an unterminated JSON string. Reading the same completed stream with LF as the delimiter recovered all 1,931 html5lib subtests with zero malformed records. The failure was in the analysis, not the journal.

**Fix**: Follow the format's delimiter when reading records. For this scratch query, split on "\n" instead of using splitlines(). Validate record coverage before diagnosing missing or corrupt test results.

**Takeaway**: **A text helper's definition of a line need not match the data format's definition of a record.**
