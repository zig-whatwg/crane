# Workflow: `sort -u` under a UTF-8 locale merges distinct paths - compare bytes, and check a list in both directions

**Date**: 2026-11-11
**Lesson**: A file list built with `sort -u` on a host whose locale is `en_US.UTF-8` loses every path that collates equal to another one; set `LC_ALL=C` at the top of any script that sorts, uniqs or `comm`s paths, and check a run list against its source in BOTH directions with counts.

**Why**: The locale's collation ignores punctuation at its first levels, and GNU `sort -u` keeps one line of each set that COMPARES equal, not of each set of equal bytes. `referrer-policy/gen/top.meta/origin-when-crossorigin/xhr.http.html` and `.../origin-when-cross-origin/xhr.http.html` compare equal; so do `euckr-decode-ksc_5601.html` and its `ksc5601` sibling. Nothing is printed: the list is just shorter.

**What Happened**: Lane v8up b4's FULL A/B window built its list with `sort -u "$G/worklist.txt"` on server1 (`LANG=en_US.UTF-8`, `LC_ALL` unset). The worklist has 13,164 distinct lines; the list had 13,117. The 47 dropped files (45 under `referrer-policy/gen/`, 2 under `encoding/legacy-mb-korean/`) hold 34,364 passing subtests in generation 216, so the "FULL" A/B read base 1,855,942 where the generation says 1,890,306. The script's only list check was one-directional (`comm -23 list base-journal` = 0: every listed path is in the base journal), which a shorter list passes. The same line was in the window scripts of lanes wr1 and style1 (copied from one another), whose earlier FULL A/Bs therefore also ran 13,117 files; the generation sweep on main, which runs the worklist unsorted, covered the 47 each time. Found only because the base total did not match the generation's published number.

**Fix**:
1. `export LC_ALL=C` at the top of every script that sorts, uniqs, `comm`s or `join`s paths (a per-command `LC_ALL=C sort` leaves the next `comm` in the locale).
2. Check a run list against its source both ways and by count: paths in the list but not the source, paths in the source but not the list, and `wc -l` of both equal. Fail before the run starts.
3. Compare the base side's total with the published number of the generation it claims to be; a difference is a list problem until shown otherwise.
4. After a run, compare its journal's record count with the source list's line count.

**Takeaway**: **A sorted list is only the list you meant in the C locale: set `LC_ALL=C` once at the top, and make every list check count both directions.**
