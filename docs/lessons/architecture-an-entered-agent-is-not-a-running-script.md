# Architecture: An entered agent is not a running script

**Date**: 2026-10-10
**Lesson**: "The JavaScript execution context stack is empty" is a question about prepared realms and JavaScript frames, not about which engine agent is entered on the thread.

**Why**: A page's V8 isolate stays entered on its thread for the page's whole life, and the host enters a realm for plenty of native work (tasks, conversions, the parser's DOM building) with no script on the stack. HTML's checkpoints ("text" mode's script end tag, create-an-element-for-a-token step 9.2) run exactly when no script is on the stack, so an answer that means "entered" skips every one of them in a page.

**What Happened**: engine.hasRunningScript - whose protocol contract is "whether the agent's execution context stack is non-empty" - was V8's "is this isolate current". Its only two callers were the HTML parser's checkpoint steps, so a page never ran either: the mutation records of the parser's own insertions were still queued (4 of them, takeRecords showed) when the next parser-inserted script ran, and slotchange events queued by a custom element's slotted children were never delivered before it. dom/nodes/MutationObserver-document.html 1/4, shadow-dom/slotchange-customelements.html 0/1, custom-elements/perform-microtask-checkpoint-before-construction.html 0/2. A tests/v8 test had pinned the wrong answer ("the current agent is running, as far as V8 can tell").

**Fix**: V8's hasRunningScript answers the contract for the current agent with the test "clean up after running script" already made: an open "prepare to run script" (prepared_depth) or v8::Isolate::HasJavaScriptOnStack. The three files above go to 4/4, 1/1 and 2/2; a custom-elements/ + html/syntax/ A/B moved nothing else.

**Takeaway**: **When an operation's name is a spec question, test it against the spec's meaning (a prepared realm, a JS frame) - an approximation that is always true where the host lives silently turns every step that asks it into dead code.**
