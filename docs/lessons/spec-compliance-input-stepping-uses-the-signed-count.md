# Spec Compliance: Input stepping uses the signed count

**Date**: 2026-10-17
**Lesson**: Compare the whole stepping mechanism: an off-step snap consumes one signed step, and arithmetic starts from the original decimal strings.

**Why**: The method name alone does not determine direction because stepUp accepts negative counts. Binary arithmetic can also turn a valid decimal result into visible rounding noise.

**What Happened**: BASE serialized number input 1.2 stepped down by 0.3 as 0.8999999999999999. Its off-step branch ignored the count, and its direction guard used the method name. The cached algorithm text described that branch, but Blink and WebKit both count a snap as the first requested signed step.

**Fix**: Read InputType::ApplyStep/applyStep and StepRange together. Parse the original number/range value, step and base as f128, retain that precision through snapping and bounds, and narrow only for the state's final serialization. Follow the browser mechanism for negative counts and the remaining count after a snap. Pin decimal subtraction, small steps, bounds, negative counts and off-step counts through the generated input interface and WPT.

**Evidence**: Native fm2_input_steps_test failed at BASE with expected 0.9, actual 0.8999999999999999. [Blink InputType::ApplyStep](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/html/forms/input_type.cc) and [WebKit InputType::applyStep](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/html/InputType.cpp). All three aligned stable browsers pass upstream input-step-float.html at WPT cc74d2669f. Validation: the native decimal-step regression, all seven new stepping fixture cases and upstream input-step-float.html pass.

**Takeaway**: **Preserve decimal inputs through arithmetic, and test direction as a signed count rather than a method name.**
