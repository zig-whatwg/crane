# Workflow: Bash pattern substitution is quadratic in a UTF-8 locale

**Date**: 2026-10-30
**Lesson**: `${var//pattern/repl}` on a large string in a UTF-8 locale can take minutes; rewrite large text with `LC_ALL=C sed`.

**Why**: In a multibyte locale, bash's pattern substitution converts and rescans the string as wide characters around each match position. The work grows with the square of the string's length.

**What Happened**: Codex row 128's gate command was 131,666 bytes (a 598-hash checker inlined twice, one line of 64 KB). tmp/remote/crane-remote.sh rewrote every command with four `${cmd//...}` substitutions before running it. On chat.local the job sat at 100% CPU for 8+ minutes without running its first line. A 5 s `sample` showed 2,291 of 2,293 samples in `wcslen` under bash frames (Q220, D571).

**Fix**:
1. crane-remote.sh now does every command rewrite through `printf '%s' "$cmd" | LC_ALL=C sed ...`, with byte-identical output on a sample command. A 70 KB line takes milliseconds.
2. Long inline payloads belong in a file the command reads (with its sha256 checked), not in the command line.

**Takeaway**: **Never run `${var//...}` over input you do not control the size of; sed under `LC_ALL=C` is linear and locale-proof.**
