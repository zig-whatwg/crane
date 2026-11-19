# Spec Compliance: A "not modelled" step can hide where the browsers apply it

**Date**: 2026-11-18

**Lesson**: When a check carries a "not modelled, stated" note, look at where every browser applies the algorithm, not only at the step the spec names. Here the missing step was also missing from a second call site the spec never mentions.

**Why**: CSP 6.7.3.1 "Is element nonceable?" is called by the spec only from the inline checks (6.7.3.3). Its step 3 needs a duplicate-attribute flag from the HTML parser, which HTML does not define (whatwg/html#3257). Crane implemented steps 1-2 for inline scripts and recorded step 3 as not modelled. All three browsers go further: they run the whole algorithm on the nonce an EXTERNAL script's fetch carries (Blink's ScriptElementBase::GetNonceForElement), so `<script src=evil.js x x nonce=abc>` and `<script src=evil.js data="<script" nonce=abc>` are blocked.

**What Happened**: content-security-policy/script-src/nonce-enforce-blocked.html failed at its inline duplicate-attribute case (line 64), the first case it reached. Adding step 3 for inline scripts got past that case, but the file still needed three more things to pass, and an inline-only fix would have looked complete:
- the seven external scripts (dangling markup or duplicate attributes) had to be refused their nonce too;
- the SVG script's violation needed its source line (the test reads `lineNumber`, and `new URL("inline")` threw where it was 0);
- the parser's html/body attribute merge needed nonce hiding (dangling-html-or-body.html, the same family).

**Fix**: The tokenizer records the parse error on its token, the tree builder on its node, and the DOM adapter on the element's rare-data flags. `dom.csp_violations.isNonceable` (steps 2-3) serves both the inline check and `nonceableScriptNonce`, which every script fetch's options use. The SVG script records its start position as an HTML script does.

**Takeaway**: **Before closing a "not modelled" step, list every place the browsers run the algorithm: a WPT file that tests the step often tests those other call sites too, and only the first failure shows.**
