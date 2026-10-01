# Testing: A count that moves between runs - diff the failure messages, not the totals

**Date**: 2026-09-30
**Lesson**: When a file's passing count differs from run to run, extract every
subtest's status AND message from each run's wptreport and diff them. The same
subtest failing with different messages in two runs is a dangling pointer being
wrapped, and the count moves with garbage-collection timing - that is, with the
files a sweep ran before.

**Why**: A journal record holds only totals, so "339, 263 and 325 passing" in
three sweeps reads like noise. The per-subtest messages say what kind of defect
it is: a wrong answer repeats itself, a use-after-free does not.

**What Happened**: `dom/ranges/Range-mutations-deleteData.html` read 236 to 339
of 564 passing across sweeps and 265-266 alone, and every lane's A/B waved it
off. Diffing three solo runs and one sweep-prefix run of the frozen main runner:

- the 282 "with unselected" subtests passed identically (207) every time; all
  the variance was in the 282 "with selected" ones;
- ~205 of those failed in `getSelection().removeAllRanges()`, as
  `getSelection(...).removeAllRanges is not a function` in one run and
  `Cannot read properties of undefined (reading 'removeAllRanges')` in another,
  for the SAME subtests, from a point mid-file that moved between runs.

`Document.call_getSelection` cached the Selection as a bare `*Instance`; the
test keeps nothing of it; a collection freed it (wrapper_cache.weakCallback ->
gc.onObjectFreed) and the next call wrapped whatever took the slot - another
object, or nothing. The same pointer was then deinit'd at the document's
teardown, into a block the arena may have reissued: `crane/fl-selection-survives-gc.html`
alone ended the frozen runner with `panic: reached unreachable code` in
`DebugAllocator.free` under the NEXT page's teardown. `document.fonts` and the
selection's range had the same shape. `document.all` and `document.styleSheets`
did not show it: they are generated `[SameObject]` caches, and the binding draws
an edge from the document's wrapper to them.

**Fix**: Document keeps each child it hands out with a `KeptChild` (a
`same_object.Pin` on the child's wrapper from the first hand-out, and a
`same_object.Link` so teardown severs only the object it made), released in
`InternalState.deinit`; Selection holds its range through `setRange`, a Pin
(addRange step 3: "by a strong reference"). Blink traces the same edges
(TreeScope::Trace visits selection_ and style_sheet_list_,
SelectionEditor::Trace visits cached_range_).

To take the per-subtest diff: run the file single-process (no `--parallel`,
so `wptreport.json` is written), load `results[].subtests[]` for the file, and
write `status \t name \t message` per subtest; `diff` two runs. The newer
runner leaves files missing from MANIFEST.json (new `crane/` tests) out of
wptreport - read their progress line instead.

**Takeaway**: **Totals that move are a symptom; the per-subtest messages are
the diagnosis. Identical subtests failing differently between runs mean
something freed is being read - look for a bare pointer to a GC-managed
object.**
