# Testing: WPT testdriver selectors can test the wrong node

**Date**: 2026-10-21
**Lesson**: Before treating an all-browser WPT pass as evidence about a node, check that testdriver sends that node to the browser.

**Why**: WPT's JavaScript testdriver passes selector strings through its automation transport. A selector can resolve to a different node from the JavaScript argument, making agreement between browsers evidence about the wrong object.

**What Happened**: `html/dom/aria-element-reflection-labelledby.html` asks for the computed name of a detached, id-less input and expects an empty string. Chrome, Firefox and Safari all passed. That initially looked like a browser exception to WebDriver's stale-element rule. Reading `tools/wptrunner/wptrunner/testdriver-extra.js` showed that its selector builder emits `:scope` for this input: it has no parent element and its root is not its document. The accessibility action resolves that selector in the document, so WebDriver receives the connected document root. A separate disconnected-role test returns the browsers' document-root role values, corroborating the mechanism.

**Fix**: Trace the argument through the JavaScript adapter, serialized action, selector resolver and browser command before inferring engine behavior. Preserve the exact subtest and browser receipts, but distinguish the test's intended node from the node actually selected. Check the normative algorithm and browser implementation for the intended operation. Do not implement a browser exception solely from a pass caused by this transport path.

Sources: WPT [selector builder and computed commands](https://github.com/web-platform-tests/wpt/blob/afe89a5df4dcc7c6bcb317b07d6eee31a383c466/tools/wptrunner/wptrunner/testdriver-extra.js), [accessibility actions](https://github.com/web-platform-tests/wpt/blob/afe89a5df4dcc7c6bcb317b07d6eee31a383c466/tools/wptrunner/wptrunner/executors/actions.py), and [WebDriver selector adapter](https://github.com/web-platform-tests/wpt/blob/afe89a5df4dcc7c6bcb317b07d6eee31a383c466/tools/wptrunner/wptrunner/executors/executorwebdriver.py).

**Takeaway**: **Browser agreement validates the operation that actually ran, not necessarily the operation the test intended.**
