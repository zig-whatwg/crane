# Spec Compliance: Color conversion keeps the destination separate

**Date**: 2026-10-09
**Lesson**: Parsing a color, resolving its context, and mapping it into an output gamut are separate algorithms.

**Why**: The same CSS color can be a stylesheet value, an HTML attribute value, or a pixel. They share conversion mathematics but have different context and clipping rules.

**What Happened**: Wiring input type=color into the CSS parser exposed two tempting shortcuts: resolve currentColor in the shared stylesheet parser, and apply CSS display gamut mapping to the input's serialized value. Both would change the wrong caller. CSS Color 4's context-free parsing entry point explicitly excludes stylesheets; its display/canvas gamut mapping is not HTML's limited-sRGB serialization.

**Fix**: Keep the property parser's keyword behavior unchanged. Give HTML a separate context-free entry point that resolves initial colors through one fixed light UA palette. Preserve floating-point channels through color-space conversion. Only the HTML destination clamps and rounds them into bytes. The default input test expects color(display-p3 1 0 0) -> #ff0000 and color(display-p3 .5 0 0) -> #8c0000 in all three browsers.

**Evidence**: HTML “serialize a color well control color,” limited-srgb steps 4.1–4.2; CSS Color 4 §4.5 “parse a CSS <color> value,” §11 “Converting Colors,” and §14.2 “CSS Gamut Mapping”; aligned stable wpt.fyi runs at cc74d2669f, html/semantics/forms/the-input-element/color.html, 27/27 in Chrome, Firefox and Safari. Integrator rulings Q20/Q23 in tmp/plans/codex-forms-questions.md.

**Takeaway**: **Share the color grammar and conversion math; let each caller choose context resolution and destination clipping.**
