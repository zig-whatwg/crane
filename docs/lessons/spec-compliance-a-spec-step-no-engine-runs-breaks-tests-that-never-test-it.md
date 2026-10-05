# Spec Compliance: A spec step no engine runs breaks tests that never test it

**Date**: 2026-10-05
**Lesson**: Following HTML's timer step 10.8.2 to the letter newly blocked three WPT files that are not about timers. The step reports the EvalError of a CSP-blocked string handler for the global, and no engine does that.

**Why**: HTML checks a string handler when the timer fires and has its EvalError "reported for global", which fires an ErrorEvent at the window. Chrome, Firefox and Safari all check at setTimeout()/setInterval() instead, report the violation, return 0 and give script nothing: Blink's DOMTimer::setTimeout (IsAllowed, AllowEval with kWillNotThrowException), Gecko's nsGlobalWindowInner::SetTimeoutOrInterval (CSPEvalChecker::CheckForWindow) and WebKit's LocalDOMWindow::setTimeout (allowEval, `return 0`). testharness turns any uncaught error into harness ERROR unless a file sets allow_uncaught_exception. Files written against the engines (script-src-trusted_types_eval_*, trusted-types-reporting-check-report-Window-sink-mismatch) call setTimeout(";") under such a policy and expect no error.

**What Happened**: The csp2 lane's TARGETED A/B for the spec form showed 3 files OK -> ERROR with their passing subtests unchanged. script-src-1_4_1 and eval-scripts-set*-blocked turned ERROR too, depending on timing. The integrator ruled for the engines' behaviour, as a stated deviation, once the three engines' code had been read and cited. Result: those files OK, eval-scripts-setTimeout/setInterval-blocked NONE-PASSED -> OK 1/1, script-sample ERROR -> OK 6/6.

**Fix**: src/browser/Context.zig initializeTimer checks the string at the call (html.code_generation.timerHandlerAllowed). An enforced block reports the violation and returns 0. The call-site comment and the commit name the spec step it replaces and cite all three engines' functions.

**Takeaway**: **Before implementing a spec step that makes script observe something new (an error event, an exception, a different return value), read what the three engines do. If none does it, WPT does not expect it, and following the letter turns unrelated files into harness ERRORs: measure it, cite the engines, and state the deviation.**
