# Spec Compliance: "Upon rejection" is a reaction, even for a promise already rejected

**Date**: 2026-09-30
**Lesson**: HTML "run a module script" step 8 reports the error "upon rejection of evaluationPromise" - a promise reaction, a microtask - so it runs after the microtasks the evaluation queued, even when evaluation rejected synchronously.

**Why**: A module that queues a microtask and then throws settles its evaluation promise before `run` returns. Reporting the value on the spot (as "run a classic script" does) puts the error event ahead of that microtask; the spec's reaction is queued behind it and runs in step 9's checkpoint.

**What Happened**: The first cut of module workers reported a synchronously rejected evaluation at once. microtasks/evaluation-order-1-throw-static-import expects `"body", "microtask", "global-error"`, and got the error first. The Window host still reports a synchronous rejection on the spot, and its evaluation-order-2.html passes anyway; why was not investigated - worth a look before trusting it.

**Fix**: worker_host.runModuleScript turns a `.report` into `engine.createRejectedPromise` and reacts to it exactly as to a pending top-level-await promise (lane/scripts e1acbff5d).

**Status (2026-10-19, lane engine1)**: the Window host now does the same. The open question above had an answer: its synchronous report ran inside the prepare scope with no V8 call on the stack, so each error listener's call returned to call depth 0 and V8's kAuto policy checkpointed after it - the first listener's microtasks ran before the second listener (microtasks/checkpoint-after-window-onerror-module.html; the worker variant passed). script_execution.runModuleScript reacts to a rejected promise like the worker, and the V8 adapter runs every host reaction step inside prepareToRunScript / cleanUpAfterRunningScript of its realm (HostEnqueuePromiseJob; engine.PromiseReactionSteps). When a window and a worker implement one algorithm, diff their shapes.

**Takeaway**: **Where the spec says "upon fulfillment" or "upon rejection", react to a promise - even one you know is settled - so the step lands behind the microtasks already queued.**
