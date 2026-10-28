# Spec Compliance: Shared CSSOM Views Need One Owner

**Date**: 2026-10-27
**Lesson**: Two `[SameObject]` attributes that represent the same collection must obtain their object from one owner; separate per-receiver caches do not establish cross-object identity.

**Why**: `[SameObject]` makes repeated reads on one receiver stable. It does not make independently constructed views of one native collection identical across two receivers.

**What Happened**: CSSImportRule.media and its associated StyleSheet.media each constructed a MediaList. The rule's view read its import media queries, while the sheet's view read a separate SheetRecord media list. Both identity and mutation sharing were therefore missing: `rule.media === rule.styleSheet.media` failed. The upstream identity test and Crane's two getter-order cases reproduced the defect.

**Fix**: For an imported sheet, reach the owner rule through the CSSOM object factory and return its generated `CSSImportRule.get_media` accessor. The two generated `[SameObject]` accessors then cache the same object. Ordinary sheets retain their own media view. Native tests exercise both getter orders and mutation; the Crane fixture also retains the view across garbage collection.

The design follows CSSOM §6.4.4 and [Blink's CSSStyleSheet::media](https://github.com/chromium/chromium/blob/cc7021d31c75bdb1ed2a95ea230abb6abcc3c663/third_party/blink/renderer/core/css/css_style_sheet.cc#L610). The generated interface remains the boundary; directly calling another implementation would bypass its identity cache.

**Browser ruling**: The integrator's 2026-10-27 probes found Firefox 158 sharing identity and writes, while Chrome 156 and Safari 27 returned separate objects and an empty child-sheet view in both getter orders. The user explicitly chose the spec plus Firefox (liaison Q79), overriding that stable-browser majority. Blink's [2026-10-09 fix](https://github.com/chromium/chromium/commit/2870b09ab93db50d68d868a145bdd5550b38d511) confirms the intended shared-owner design; it had not reached the probed Chrome version. Probe receipts are in the lane's `tmp/probe-q79/`.

**Takeaway**: **Sharing native data is not the same as sharing the object that exposes it. Test identity in both access orders.**
