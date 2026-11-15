# Workflow: An apostrophe inside `${VAR:?message}` swallows the script on the Macs' bash 3.2 - keep quotes out of parameter-expansion words, and let the dry run print every check

**Date**: 2026-11-15
**Lesson**: macOS ships bash 3.2 as /bin/bash. In `"${WIN:?the cost window's out dir}"` it reads the apostrophe as the start of a single-quoted string, even though the whole expansion sits inside double quotes. Everything up to the next apostrophe in the file becomes part of that one word. The script can still parse - and then silently skips every line it swallowed.

**Why**: Window scripts on the pool's Macs run under `bash script.sh`, which is 3.2 there (Linux hosts and Homebrew have 5.x, where the same line is fine). Bash 3.2 scans the word of `${parameter:?word}` for quotes on its own, without regard to the enclosing double quotes. An English possessive in an error message is enough.

**What Happened**: Lane dm2 wrote a follow-up measurement script with `: "${T:?tip console dir}" "${A:?main console dir}" "${WIN:?the cost window's out dir}" "${PB:?perf_bench}"`. First symptom: `bash -n` reported "syntax error near unexpected token `)'" 28 lines further down, at a `case` branch inside the swallowed region; the lane "fixed" that by rewriting the branch as an `if`, which made the script parse. Second symptom, on the host: the run printed its first step's banner and died with `OUT: unbound variable`. Seventeen lines - every input check and the `OUT=` assignment - had been swallowed as part of the `:` command's third argument, up to an apostrophe inside a JavaScript string. `bash -x` showed it in one line: `+ : <T> <A> '<WIN>)()).cloneNode(true);'`. Nothing had been measured, so nothing wrong was reported; but a script whose checks are skipped is exactly the script the window rule exists to prevent.

**Fix**:
1. No apostrophe, quote or backquote inside the word of `${VAR:?...}`, `${VAR:-...}` or `${VAR:+...}`. Write "the out dir of the cost window".
2. When `bash -n` fails far from anything you just wrote, suspect an unbalanced quote ABOVE the reported line, not the line itself. Do not restructure the reported line to make the error go away.
3. A dry run must PRINT each check it performs (`check: ...` lines). A dry run that prints fewer check lines than the script has checks did not run them: compare before trusting "passed".
4. `bash -x script 2>&1 | head -40` under the host's own bash is a ten-second test of a new script; run it on a Mac host, not only locally if the local bash is newer.

**Takeaway**: **On the pool's Macs a script runs under bash 3.2, where a possessive in a `${VAR:?message}` turns the following lines into data. Keep quotes out of expansion words, and count the dry run's check lines - a parse that succeeds says nothing about which lines will run.**
