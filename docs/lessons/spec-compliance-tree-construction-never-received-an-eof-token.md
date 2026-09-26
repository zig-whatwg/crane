# Spec Compliance: Tree construction never received an EOF token

**Status**: the EOF part is fixed; the "NOT fixed" section below is as of 2026-09-22 - check before relying on it.

**Date**: 2026-09-22
**Lesson**: `TreeBuilder.parse` broke out of its loop when the tokenizer returned
`null`, so no `.eof` token was ever dispatched and the `.eof` branch of every
insertion mode was dead code.

```zig
while (true) {
    const token = try self.tokenizer.nextToken();
    if (token == null) break;        // end of input exits HERE
    ...
    if (tok == .eof) break;          // unreachable
}
```

**Why it matters**: HTML §13.2.6 gives EOF real work. "In head" at EOF pops the
head element and reprocesses in "after head", which inserts an implied `<body>`.
Every "stop parsing" step is an EOF step.

**What is FIXED**: EOF is now synthesised and processed when the tokenizer
signals end of input. Verified no regressions - dom/nodes 40 files per-file:
23 OK->OK, 14 TIMEOUT->TIMEOUT, 2 ERROR->OK, 1 CRASH->OK, 0 regressions.

**What is NOT fixed, and is the next thing to look at**: `document.body` is
STILL null for a document whose content is entirely head-level, which is most
WPT files. Do not re-derive the following - it is all measured:

* The tree builder DOES create the implied body -
  `handleAfterHeadAnythingElse` builds it and calls `insertAtAppropriatePlace`,
  the SAME path that successfully inserts `<head>`.
* `in_head`, `after_head` and `text` EOF handlers are each individually correct,
  including text mode's reprocess.
* `tree_builder.parse` is the ONLY tokenizer driver outside document_write's
  tests, so there is no second parser path to blame.
* With an explicit `<body>` tag the element appears:
  `html children: [HEAD, BODY]`. Without one: `[HEAD]`.

So the gap is between the tree builder creating that node and the DOM adapter
receiving it. Instrument `dom_adapter_on_child_appended` for the body node next.

**Takeaway**: **"The loop ended" and "the parser finished" are different
claims.** A tokenizer that reports end-of-input out-of-band leaves every
end-of-input rule in the consumer unreachable, and nothing fails loudly - the
document is simply missing the parts that only EOF would have added.
