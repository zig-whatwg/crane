# Spec Compliance: Environment defaults distinguish absence from zero

**Date**: 2026-10-25
**Lesson**: An unavailable environment variable uses its fallback; a defined zero does not, and a browser lacking a newer variable is not evidence against its default.

**Why**: CSS Env 1's substitution step 1 asks whether a variable exists with the supplied number of indices. Only a missing value proceeds to the fallback in step 2. Treating all unobscured or unsupported geometry as zero changes author-visible behavior.

**What Happened**: Row 121 probed all 25 standard names using a custom property containing `env(name, ROW121_MISSING)`, recording both specified and computed values. Chrome 155, Firefox 158 and Safari 27 agreed on zero safe-area insets. Chrome alone defined maximum safe-area insets, keyboard insets and preferred text scale. All three left titlebar values undefined without an overlay. Chrome accepted indexed segment syntax but had no segment values; Firefox and Safari rejected the indexed syntax entirely. A computed zero longhand alone would not distinguish these cases from a rejected declaration's initial value.

**Fix**: Record specified text to distinguish parse rejection from missing values, and use a conspicuous fallback in a custom property to distinguish a defined zero from absence. Under golden rule 2, take the majority among implementations of that variable; retain a newer specification's default when one browser ships it. In the platform protocol, represent absence with `null`, separately from `0`. Keep segment index lookup sparse: a normal rectangular viewport does not imply a `(0, 0)` environment entry.

Sources: [CSS Env 1 substitution](https://drafts.csswg.org/css-env-1/#env-function), [Blink defaults and indexed lookup](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/css/style_environment_variables.cc), [WebKit environment values](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/style/StyleEnvironmentVariables.cpp), and the integrator's three-browser probe at `tmp/analysis/integrator-probes-1025a/` (2026-10-25).

**Takeaway**: **Probe availability, parsing and value separately; zero and undefined are different environment answers.**
