# Spec Compliance: XML Serialization Needs Active Namespace Bindings

**Date**: 2026-10-17
**Lesson**: A namespace prefix can be reused only when its current binding names the required namespace.

**Why**: A historical prefix-to-namespace pair does not establish the binding at the node being serialized. A descendant can shadow it. Generated prefixes must also avoid names already bound in the current scope.

**What Happened**: XML serialization searched every ancestor pair and reused a shadowed prefix. Its unconditional `ns1` generator could emit two conflicting declarations on one element. Several upstream WPT assertions expected these outputs because they followed the unmaintained DOM Parsing draft. Current Chrome, Firefox and Safari all reject those assertions, although their replacement prefixes sometimes differ.

**Fix**: Search bindings from the innermost scope, ignore shadowed candidates, and generate an unused prefix. Restore the binding stack when leaving an element. Compare each behavior with aligned browser subtest results, including explicit default declarations and element prefixes. Construct regression DOMs directly so a parser defect cannot impersonate a serializer defect.

The design references are Blink's `NamespaceContext`, `RetrievePreferredPrefixString` and `GeneratePrefix` in [markup_accumulator.cc](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/editing/serializers/markup_accumulator.cc), and Gecko's `ConfirmPrefix` in [nsXMLContentSerializer.cpp](https://github.com/mozilla-firefox/firefox/blob/main/dom/serializers/nsXMLContentSerializer.cpp). The evidence is [XMLSerializer at aligned revision df642c4142](https://wpt.fyi/results/domparsing/XMLSerializer-serializeToString.html?sha=df642c4142).

**Takeaway**: **An increased WPT pass count is not proof of namespace correctness when the test expects an obsolete draft's invalid output. Record browser-majority changes and their intentional WPT losses explicitly.**
