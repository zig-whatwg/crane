# Spec Compliance: "Upon rejection" is a reaction, even for a promise already rejected

**Date**: 2026-09-30
**Lesson**: HTML "run a module script" step 8 reports the error "upon rejection of evaluationPromise" - a promise reaction, a microtask - so it runs after the microtasks the evaluation queued, even when evaluation rejected synchronously.

**Why**: A module that queues a microtask and then throws settles its evaluation promise before `run` returns. Reporting the value on the spot (as "run a classic script" does) puts the error event ahead of that microtask; the spec's reaction is queued behind it and runs in step 9's checkpoint.

**What Happened**: The first cut of module workers reported a synchronously rejected evaluation at once. microtasks/evaluation-order-1-throw-static-import expects `"body", "microtask", "global-error"`, and got the error first. The Window host still reports a synchronous rejection on the spot, and its evaluation-order-2.html passes anyway; why was not investigated - worth a look before trusting it.

**Fix**: worker_host.runModuleScript turns a `.report` into `engine.createRejectedPromise` and reacts to it exactly as to a pending top-level-await promise (lane/scripts e1acbff5d).

**Takeaway**: **Where the spec says "upon fulfillment" or "upon rejection", react to a promise - even one you know is settled - so the step lands behind the microtasks already queued.**
