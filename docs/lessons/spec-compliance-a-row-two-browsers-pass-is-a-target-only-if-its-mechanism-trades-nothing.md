# Spec Compliance: A row two browsers pass is a target only if its mechanism trades nothing

**Date**: 2026-11-21
**Lesson**: Before classing a subtest "two browsers pass, Crane fails" as plain work, find the browsers' mechanism behind it and count the rows Crane passes that the same mechanism would flip.

**Why**: The WPT editing data mixes rows from the spec's reference implementation with rows later rewritten to one browser's behaviour, so a majority pass in one row can come from a rule the same majority fails in hundreds of others.

**What Happened**: Lane edit4 mapped 205 editing/ rows as two-browser passes. On inspection, several were the visible edge of a mechanism that loses passing rows. Chrome and Safari answer false for every value command's queryCommandIndeterm: that passes 3 "indeterm after" rows but fails the FPF "indeterm before" rows Crane passes with Firefox and the spec. They toggle strikethrough by the selection START's style: that passes 1 row and fails the many FPF toggle rows. They insert an <img> with no src for insertImage "" and parse fontSize "15px" as a legacy size: each is +1 in event.html against 2 and 4 rows Crane passes on the spec. Only a Chrome 157 headless probe (return value, input events, DOM per command) and a grep of the data for the same inputs showed it.

**Fix**: For each candidate cause: (1) name the browsers' mechanism, using their source or a probe (`"Google Chrome" --headless=new --dump-dom file://...`); (2) find every data row the mechanism reaches, with the same command and the same kind of input; (3) count Crane's passing rows it would flip. If any would flip, it is a ruling (map class B), not a target.

**Takeaway**: **A majority pass is evidence about one row; the mechanism is what you implement - count every row it touches, passing ones included, before calling it a target.**
