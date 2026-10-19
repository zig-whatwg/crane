# Spec Compliance: Window frame membership and order are separate

**Date**: 2026-10-19
**Lesson**: Window excludes shadow-tree frames but indexes its remaining navigables in insertion order, even when DOM tree order differs.

**Why**: HTML's document-tree child navigables algorithm describes both membership and tree order. Browser behavior preserves the older insertion-order rule for Window indexing. Reusing the algorithm's list without checking ordering can fix shadow exclusion while regressing ordinary frames.

**What Happened**: Switching Window's length, index and name computations to `dom.navigables.childNavigablesOf` excluded shadow frames correctly. The targeted A/B then changed `html/browsers/the-window-object/accessing-other-browsing-contexts/indexed-browsing-contexts-01.html` from 3/3 to 2/3. Parser foster parenting placed `fr5` before `fr4`, and script inserted `fr3` before `fr4`; the new list returned `[fr5, fr3, fr4]`, while the test and all three browsers expected `[fr4, fr5, fr3]`.

**Fix**: Keep the document-tree membership list, then reorder its entries in place according to the parent navigable's existing child list. No additional holder or allocation is needed. Pin both shadow exclusion and insertion order: moving an existing frame earlier in the DOM does not move its Window index earlier, and a newly inserted frame is indexed last. Keep the owning Window tests separate from the engine adapter's lazy child-Window creation path.

The integrator's row 81 Q15 ruling follows the browsers: the tree-order wording came with the navigables cleanup, but no browser adoption, implementation commitment or lag evidence was found. Re-check this decision when the spec or WPT changes. The aligned stable [Chrome, Firefox and Safari runs](https://wpt.fyi/results/html/browsers/the-window-object/accessing-other-browsing-contexts/indexed-browsing-contexts-01.html?run_id=6244643405824000&run_id=6213611998674944&run_id=6209999629189120) all pass 3/3. A local Chrome 155.0.8059.84 probe independently confirmed both DOM reordering and foster parenting.

[WHATWG issue 1336](https://github.com/whatwg/html/issues/1336) records the older insertion-order language. WebKit's [FrameTree.cpp](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/page/FrameTree.cpp) also separates these concerns: `appendChild` maintains frame order, while `scopedChild` walks that list and filters by `TreeScope`.

**Takeaway**: **Verify membership and ordering independently when substituting a shared traversal helper; a correct filter does not prove a compatible order.**
