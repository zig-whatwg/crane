# Spec Compliance: Step mismatch needs the remainder before rounding

**Date**: 2026-10-09
**Lesson**: Checking whether an f64 quotient is an integer can discard the very fraction a numeric step constraint needs to inspect.

**Why**: At large quotients, adjacent representable floating-point values are already integers. Promoting that quotient later cannot recover its remainder.

**What Happened**: Input validation treated value `17` and step `3e-15` as aligned because their f64 quotient rounded to an integer. The WPT numeric case passes in Chrome, Firefox and Safari. The converse case, `-12345678.9` with step `1e-12`, deliberately has no mismatch in the browsers once the quotient exceeds their meaningful precision range.

**Fix**: Read Blink's `StepRange::StepMismatch` and WebKit's `StepRange::stepMismatch`, including their precision cutoff and real-number tolerance. Parse the original value, step and base as f128 and calculate the remainder before rounding away its fraction. Apply the browser majority's 2^53 quotient cutoff and step/2^24 tolerance. Pin small decimal steps, nonzero decimal bases and very large quotients. This calculation affects validation reads only, not the stored value or input serialization.

**Evidence**: [Blink StepRange](https://raw.githubusercontent.com/chromium/chromium/main/third_party/blink/renderer/core/html/forms/step_range.cc), [WebKit StepRange](https://raw.githubusercontent.com/WebKit/WebKit/main/Source/WebCore/html/StepRange.cpp); aligned stable wpt.fyi runs at cc74d2669f, `html/semantics/forms/constraints/form-validation-validity-stepMismatch.html`, numeric tiny-step case passes in all three engines.

**Takeaway**: **Preserve the original precision through the remainder calculation; an integral rounded quotient is not proof of step alignment.**
