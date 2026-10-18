# Spec Compliance: Unicode casing context is not a category check

**Date**: 2026-10-17
**Lesson**: Full Unicode casing needs original-string context and derived properties; CSS capitalization has a separate word-boundary context.

**Why**: UnicodeData's simple mappings do not include expanding or conditional mappings. Its general categories do not fully define Cased, Case_Ignorable or Soft_Dotted. A code point can be both cased and case-ignorable: U+0345 is one example.

**What Happened**: Implementing innerText exposed the absence of a reusable full case mapper. An ASCII fallback would have missed sharp s and Turkish i in existing WPT. Unicode's final-sigma condition also requires a possessive scan: skip every case-ignorable character before testing whether the next character is cased. Checking Cased first gives the wrong answer for U+0345.

**Fix**: Generate mappings from hash-pinned UnicodeData and SpecialCasing, plus the exact derived properties from DerivedCoreProperties and PropList. Evaluate conditions against the original input, never a prefix already transformed. Native tests pin final sigma, Lithuanian dots and Turkish/Azeri context, including empty and expanding mappings. For CSS, follow Blink's `LayoutText::TransformAndSecureText` / `ComputedStyle::ApplyTextTransform` and WebKit's `applyTextTransform`: upper/lowercase context is one original Text node; only capitalization carries preceding word context across inline nodes. The innerText collector keeps these contexts separate.

**Takeaway**: **Use the full mapping data and exact context properties; do not substitute ASCII, general categories, or already-mapped output.**
