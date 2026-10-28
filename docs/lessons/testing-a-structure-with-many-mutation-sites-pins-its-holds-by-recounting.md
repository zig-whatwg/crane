# Testing: A structure with many mutation sites pins its holds by recounting them

**Date**: 2026-10-28
**Lesson**: When a holder's membership changes at dozens of sites (a parser's stack of open elements, its formatting list, its head and form pointers), route every change through a few helpers that keep a per-node membership count, and under test recount the structures after every run and compare: then every existing test of that code pins the holds, not just the new ones.

**Why**: Refcount step 5a made the HTML tree builder's structures hold their DOM nodes counted (WebKit's HTMLStackItem `RefPtr<ContainerNode> m_node`). The builder mutates those structures at about 45 places - 27 pushes, removals in the pops, an insert and two replacements in the adoption agency, the formatting list's appends, removals and replacements, the head and form pointers - and the fragment parser and DOMParser set some of them from outside. One site missed leaves a node held forever (a leak once counts decide) or released early (a use-after-free once they do), and a new test can only cover the paths its inputs reach.

**What Happened**: Lane refcount6 gave each tree node a `structure_refs: u8` (how many structures name it), changed only by builder helpers (pushOpenElement, replaceOpenElement, replaceFormattingNode, setHeadElement, setFormElement, the pops), with DOM-adapter callbacks on 0 -> 1 and 1 -> 0. Under `builtin.is_test` each `parse()` ends with `structureHoldsConsistent()`: it recounts every structure into a map and compares each tree node's `structure_refs`, the whole tree and the builder's detached nodes included, and logs an error on a mismatch, which fails the test. Every one of the ~900 existing html tests then exercised the counts. It caught the fragment parser and DOMParser, which pushed their root and set their form pointer directly. The check runs only in unit tests, not in the WPT runner, whose Crane modules are built Debug too.

The mechanical part had its own trap. `perl -pi -e 's/try self\.open_elements\.append\(/try self.pushOpenElement(/g'` also rewrote the line inside pushOpenElement itself, so every push recursed until the stack ran out. The test binary sat at 100% CPU with no output for ten minutes. `sample <pid> 2` named `pushOpenElement` recursing in one call.

**Fix**:
1. A per-node membership count, changed only by helpers; the adapter hears 0 -> 1 and 1 -> 0 and takes or drops one counted reference.
2. `structureHoldsConsistent()` (O(tree)) after every parse under `builtin.is_test`, as an error log.
3. External writers (the fragment parser, DOMParser) go through the same public helpers.
4. After a sed that routes calls through a helper, read the helper's own body. And a test stuck at full CPU is sampled (`sample <pid>`) before anything else.

**Takeaway**: **Pin a hold that many sites change with a recount under test, so the existing test suite checks it - and after routing calls through a helper by sed, read the helper: it calls itself now.**
