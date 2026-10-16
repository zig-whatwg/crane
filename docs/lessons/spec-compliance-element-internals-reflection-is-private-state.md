# Spec Compliance: ElementInternals reflection is private state

**Date**: 2026-10-14
**Lesson**: Follow a reflected attribute's receiver before choosing its storage or tree-scope rules.

**Why**: ARIAMixin is shared by Element and ElementInternals, but HTML gives them different reflected targets. The former changes public attributes; the latter stores default accessibility semantics independently. The generated delegate can still select an includer's impl during the mixin migration.

**What Happened**: Element's nullable string reflection already passed WPT while all 49 ElementInternals accessibility-value tests failed. The unused ARIAMixin impl looked like the shared implementation, but generated ElementInternals delegates called its own stubs. Routing those stubs through the Element reflector would mutate author attributes and enqueue the wrong reactions.

**Fix**: Read HTML 2.6.1 and 4.13.7.4 and WAI-ARIA 6.3.2/6.3.4. Implement the selected internals accessors using separate owned nullable strings, preserving case, invalid values and the distinction between null and empty. Test both receivers and verify that setting a default never changes the public attribute or fires attributeChangedCallback. For references, compare CURRENT browser sources: shipped Chrome and Firefox 157 return explicitly set internals references without the general HTML reflection algorithm's scope filtering, but current Gecko (mozilla-firefox/firefox, bug 2077803) and WebKit heads filter by shared shadow-including root. Read Gecko from mozilla-firefox/firefox, never the archived mozilla/gecko-dev mirror. Keep the deviation explicit in code and test it.

**Status**: 2026-10-15 - the Gecko evidence was corrected at merge (row 39 review); the engines are moving to filtering.

**Takeaway**: **A shared IDL member does not imply a shared reflected target or identical browser algorithms.**
