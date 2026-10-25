# Spec Compliance: Registration validation must see dependencies simplification removes

**Date**: 2026-10-25
**Lesson**: Check a registered initial value's computational independence on its matched source tokens, because numeric simplification can erase dependencies.

**Why**: A simplified expression answers what the expression computes, not which author-supplied units and functions participated. Registration has a stricter, separate validity question.

**What Happened**: The first typed-value test accepted `calc(1em / 1em)` as an independent number: the existing math owner had correctly simplified it to `1`. Fixed `random()` also simplified before a query could inspect its tree. Chrome 155, Firefox 158 and Safari 27 rejected both registration cases. Blink's then-current source accepted fixed random values, but the shipping browser behavior differed. The integrator's probes also showed that colors and images are accepted without dependency traversal, even a gradient with an `em` stop.

**Fix**: At registration time only, pass the exact initial-value source alongside the typed value that matched the syntax. For numeric and transform components, walk existing tokenizer tokens for font/container units and element-dependent functions before relying on the computed representation. For universal syntax, identify arbitrary substitution function tokens. Follow the browser ruling for color/image components without traversing them. Keep this validation out of the shared numeric parser and ordinary style computation. Native tests pin canceled relative units, nested fixed random, viewport units, percentages, transforms, and an image with relative lengths.

**Takeaway**: **An optimized value is not evidence that its source satisfied a separate dependency restriction. Preserve or inspect that evidence at the restricted operation.**
