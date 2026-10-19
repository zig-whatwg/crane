# Spec Compliance: Empty input can create fragment structure

**Date**: 2026-10-19

**Lesson**: An empty string is not an empty HTML fragment in every context.

**Why**: The HTML fragment parser resets its insertion mode from the context element. For an HTML `html` context, processing EOF still creates `head` and `body`.

**What Happened**: Element.innerHTML unconditionally replaced all children with nothing for empty input. `domparsing/innerhtml-empty-document-element.html` failed even though the existing parser had the required context setup. Chrome, Firefox and Safari all pass that upstream test.

**Fix**: Preserve the shortcut for ordinary contexts, but let an HTML `html` element in an HTML document reach the normal parser. Check the local name before the existing namespace/document predicate so ordinary empty setters avoid a document lookup. Keep XML and foreign-namespace controls in the regression tests.

The algorithm is [HTML fragment parsing](https://html.spec.whatwg.org/multipage/parsing.html#html-fragment-parsing-algorithm), particularly resetting the insertion mode and consuming the input through EOF. Blink's [Element::SetInnerHTMLInternal](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/dom/element.cc) likewise guards its empty shortcut with `HasNonInBodyInsertionMode()`.

**Takeaway**: **Prove a parser shortcut for its context, not just its input length.**
