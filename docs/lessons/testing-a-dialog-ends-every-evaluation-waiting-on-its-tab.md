# Testing: A dialog ends every evaluation waiting on its tab, even one answered at once

**Date**: 2026-11-21
**Lesson**: Through BrowserHost, a simple dialog opening in a tab, whether a host answers it later or inside the dialog_opening callback, ends every evaluation and readiness wait on that tab with error.UserPromptOpen (WebDriver's unexpected-alert behaviour). A test that triggers a prompt runs the trigger and its wait in ONE evaluation that expects that error, then evaluates the wait again.

**Why**: `BrowserHost.promptOpened` hears `dialog_opening` before any claimer answers. It abandons the tab's pending waiters (`EvaluationWaiter.abandoned`), and their answers are dropped when the script ends. An answer given in the callback ends the pause at once (`simple_dialogs.show` finds the serial answered), but the waiters are already gone.

**What Happened**: Lane cdph2 wrote the beforeunload tests for "one unloadPromptShown per check": a frame navigation over two documents, and `history.go(-2)` taking two frames across documents. A claimer that answers in the callback keeps the Browser's thread from pausing. The first sketch evaluated the trigger (`outer.srcdoc = ...`) and then awaited the load in a second evaluation. A traversal's beforeunload runs in a later task, so the prompt could open during either evaluation, and the test would race.

**Fix**: Set up the promise to wait on before the trigger. Then evaluate `trigger; promise` with `await_promise` and expect `error.UserPromptOpen`. The prompt must open before the promise settles, because beforeunload precedes the unload and commit. Then evaluate `promise` again and check its value and the claimer's prompt count. A second, wrong prompt is still counted by the claimer, whichever evaluation it ends. (tests/browser/cdph_dialogs_test.zig, `Answerer`.)

**Takeaway**: **Any evaluation pending on a tab when a dialog opens is lost, even if a host answers in the callback. Put the trigger and the wait in one evaluation that expects UserPromptOpen, read the result from a second, and count prompts in the claimer, not from the evaluations.**
