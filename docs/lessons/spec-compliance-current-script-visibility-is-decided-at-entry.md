# Spec Compliance: currentScript visibility is decided at execution entry

**Date**: 2026-10-19
**Lesson**: Select currentScript when a classic script starts, then restore the saved value after execution.

**Why**: HTML's execute-script step 6.2 sets the document's currentScript to null for a script whose root is a shadow root. A script can move itself while executing, and nested execution temporarily replaces the designation. Filtering the getter by the script's current root changes the result after either move.

**What Happened**: Crane's HTML and SVG execution paths always stored the executing element. External shadow scripts therefore exposed themselves. The regression checks an external shadow script, a nested document script, restoration to null, and moving the outer script into the document. A separate case moves a running document script into a shadow root and still expects that script.

**Fix**: At each setting site, inspect the root once and select the script or null. Keep the existing save/restore operation and the unfiltered Document.currentScript getter. SVG needs its own regression because it has a separate execution path despite sharing the HTMLOrSVGScriptElement attribute.

WebKit's [CurrentScriptIncrementer](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/dom/CurrentScriptIncrementer.h) and Gecko's [AutoCurrentScriptUpdater](https://searchfox.org/mozilla-central/source/dom/script/ScriptLoader.h) make this entry-time choice and restore the previous value. Their script-element processing covers both HTML and SVG.

**Takeaway**: **A designation captured at an algorithm boundary must not be recomputed from mutable tree state by its getter.**
