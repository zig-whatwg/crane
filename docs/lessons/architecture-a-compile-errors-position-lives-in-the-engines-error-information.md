# Architecture: A compile error's position lives in the engine's error information, not in the thrown value

**Date**: 2026-09-26
**Lesson**: Routing a string timer handler through `runClassicScript` + a reporter that passes only the thrown value would have regressed `compile-error-in-setTimeout.html`, whose onerror filename must be `location.href`.

**Why**: For a SyntaxError from the parser, the error object carries no stack frame in the script (it never ran); `report_exception` re-deriving filename/line/col from the value cannot recover them. Only the engine's error information from the failed compile (`V8ErrorInfo`) has them - which is why `report_exception.Options.info` exists.

**Fix**: Until report_exception takes a `*const runtime.ErrorInfo`, the string handler stays on `runTimerHandlerString` through one marked pass-through (`TODO(engine adapter): transitional`).

**Takeaway**: **When a report crosses the engine seam, carry the engine's error information, not just the value; the value alone loses a parse error's position.**
