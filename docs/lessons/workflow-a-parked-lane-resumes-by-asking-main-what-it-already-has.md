# Workflow: A parked lane resumes by asking main what it already has

**Date**: 2026-10-16
**Lesson**: Before merging main into a lane that was parked for weeks, list the lane's items and find each one on main. Other lanes often ported pieces of it by then, and the merge would only fight their ports.

**Why**: A parked lane's commits stay on its branch, but its design does not stay there. The integrator hands its finished items to later lanes as "port this (granted)". Those lanes re-implement the items on a newer main, under new commit hashes and sometimes in other files. Git cannot tell a port from an unrelated change. A merge of the old branch therefore conflicts on every ported item, or, worse, applies an item twice.

**What Happened**: Lane serial stopped on 2026-10-05, 914 commits behind main, with six items and an ungated WIP commit. By 2026-10-16:
- Lane wasmser had ported item 1 (WebAssembly.Module serialization) as 8b365d3349, item 4 (cross-origin postMessage serializing in the caller's realm) as 435021f2a9, and the handoff's open "dedicated worker's agent cluster" item as 9feeb5f976.
- Lane oac had redone the WIP (Origin-Agent-Cluster) as f2784456a0..2fdc14d98b.
- Two leak fixes had landed independently as 7a929a0b53 and f7e49051c0.

Only item 2 (resizable ArrayBuffer transfer) and item 3 (transfer-list objects inside the value) were missing. `git log main --grep`, a grep for each item's distinctive identifiers (`GetWasmModuleTransferId`, `agentClusterOf`, `maxByteLength`, a `transferred` argument), and the latest sweep's results for each item's WPT files settled it in minutes. The two missing items were ported onto a fresh branch from main: item 2's patch applied as it was, because main's envelope code was the lane's own as ported.

**Fix**:
1. List the lane's commits (`git log <base>..<branch>`) and the handoff's open items.
2. For each item, check main three ways: `git log main --grep=<words>`, a grep for its code, and the item's WPT files in the newest `wpt-results/sweep-*` journal.
3. Where most of the work is already on main, start a fresh branch from main. Port the remaining items' designs, and `git show <sha> -- <file> | git apply -3` where a file is unchanged.
4. Name the superseded commits in the report, then retire the old branch.

**Takeaway**: **A stale branch's diff says what it changed, not what main still lacks. Ask main item by item before merging.**
