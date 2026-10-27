# Testing: WPT subtest names are JSON strings

**Date**: 2026-10-26
**Lesson**: Preserve subtest names as JSON strings when saving or comparing passing results; a test name can contain literal line breaks.

**Why**: WPT names are arbitrary strings. Writing a URL, a tab and a name per line does not create a safely parseable TSV when the name itself contains newlines. Splitting such a file can lose part of a name or invent a new record.

**What Happened**: The CSS Text lane froze 2,617 passing whitespace-related names. A preflight comparison failed while splitting the TSV because 212 names contained line breaks. The names had been captured correctly, but the later line-oriented reader could not recover them. A separate coverage check found three recorded Canvas textAlign names whose IDL sources were absent from the execution list.

**Fix**: Save URL/name records as JSON, or compare the original wptreport JSONL directly. Read JSONL using actual LF record boundaries, preserve query and worker variants and repeated-name occurrences, and compare the resulting URL set with the executed-source manifest. For the existing TSVs, recover names from structured results and reproduce the old bytes exactly before replacing the comparison representation. Keep the old hashes as provenance.

**Takeaway**: **An exact-name regression check needs a lossless string format and a coverage check; line counts alone prove neither.**
