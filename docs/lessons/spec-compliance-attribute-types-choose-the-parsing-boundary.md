# Spec Compliance: Attribute types choose the parsing boundary

**Date**: 2026-10-25
**Lesson**: Choose an attr() type before parsing its attribute value: raw strings, primitive numbers and type(<syntax>) have different substitution rules.

**Why**: Tokenizing every attribute first destroys literal comments and whitespace. Substituting every attribute first turns a raw string containing `var()` into a dependency, and can introduce cycles that do not exist. Parsing just the first numeric token accepts invalid trailing input.

**What Happened**: Row 122's review of CSS Values 5 §8.7 and Blink's CSSAttrType showed three distinct paths. The integrator's Chrome 155 / Firefox 158 probe also found different handling of numeric whitespace, comments and trailing tokens. Neither browser implemented the entire numeric algorithm, so the spec decided the split cases; both browsers rejected resolution units, so those select the fallback.

**Fix**: Preserve raw attribute text until the type is selected. Omitted/raw-string types serialize the literal as a CSS string. Number/unit types tokenize, require exactly one number after whitespace and comments, and clamp to the engine's finite range. Only type(<syntax>) invokes the shared substitution engine and shared syntax matcher. Keep an absent fallback distinct from an explicit empty sequence, and evaluate only the selected fallback. Test these boundaries independently, including an attribute whose literal value contains `var()`.

**Takeaway**: **The type selects when text becomes tokens and when tokens acquire dependencies.**
