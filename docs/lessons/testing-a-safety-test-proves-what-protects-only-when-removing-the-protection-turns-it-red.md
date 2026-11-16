# Testing: A safety test proves what protects only when removing the protection turns it red

**Date**: 2026-11-16
**Lesson**: A test that "tries to free X under the walk and passes" says nothing about WHY it passes until the suspected protection is taken out and the test fails; with two independent protections, both must come out before it can.

**Why**: Lane uaf1 flagged that the event dispatch walk keeps raw addresses of the path's nodes across listener calls. Reading found a protection - the path takes a counted reference on each node (`DispatchPath.hold`, as WebKit's EventContext, Blink's NodeEventContext and Gecko's EventTargetChainItem hold theirs) - and tests were written that remove the path inside a listener, collect, and make thousands of same-size nodes whose listeners must never run. They passed. They also passed with `path.hold()` deleted: nothing can be freed inside a listener at all, because the agent's teardown queue frees nothing while a callback invocation is on its stack. A second round moved the frees into a microtask queued by the listener, "where the script stack is empty" - and still passed without the holds: the engine performs that microtask checkpoint inside the callback's invocation, so the depth rule covers it too. Three written explanations of what the tests proved were wrong before a mutation run corrected each.

**What Happened**: Four runs of the same ten tests, the mutations made in a pool mirror only (chat2.local, Debug, the freed-block instrument on): as the code is, 10 of 10; `path.hold()` removed, 10 of 10; the queue made to run what it owes at every binding exit, 10 of 10; both, one test fails - a native dispatch whose ancestor's listener queues a microtask that takes the REST of the path out of the document: its log reads `c:body, micro, NEWCOMER, NEWCOMER, t:details`, the walk calling the listeners of the two nodes that took the freed nodes' slots. Only that test had teeth, and only against both protections at once: in the others the listener ran on a node of the tree being freed, and that kept the tree.

**Fix**:
1. For every safety property a test claims, name the mechanism and delete it in a scratch build (a pool mirror, never a commit): the test must fail. If it passes, something else protects - find it and delete that too.
2. When two mechanisms each suffice, say so where the code is (EventTarget.zig's `Listeners` comment does), with the four results, so nobody removes one as redundant on the strength of a green suite.
3. Give the failure a voice that does not depend on a crash: the newcomers' listeners log a word, so a walk that reaches a reissued slot fails an assertion in every build, production included.

**Takeaway**: **A passing safety test names its protector only by mutation: remove the protection in a scratch build and watch the test fail - and when it does not, you have found a second protection, not a proof.**
