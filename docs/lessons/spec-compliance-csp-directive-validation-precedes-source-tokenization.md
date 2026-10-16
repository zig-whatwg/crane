# Spec Compliance: Validate a CSP directive before splitting its sources

**Date**: 2026-10-14
**Lesson**: A malformed CSP directive must be ignored as a whole, and its whitespace is Infra's five bytes.

**Why**: CSP §2.2.1 explicitly rejects non-ASCII tokens, but its wording alone does not describe the control-byte validation browsers also perform. Zig's ASCII whitespace set additionally includes vertical tab.

**What Happened**: Crane accepted control/DEL bytes in directives and treated VT as a separator. The frozen baseline failed eight invalid-bytes subtests and four only-valid-whitespaces subtests. Treating the bad byte as one unknown source still left the surrounding restrictive directive active.

**Fix**: Validate the entire semicolon-delimited directive before recording its name or tokenizing its sources. Accept visible ASCII and only TAB, LF, FF, CR and SPACE. Keep first-wins semantics among valid directives. A native allocator-checked byte matrix and isolated Crane fixtures reproduce the old behavior.

Browser evidence: aligned stable WPT cc74d2669f passes invalid-bytes 18/18 and only-valid-whitespaces 28/28 in Chrome, Firefox and Safari. The design follows [Gecko policy parsing](https://github.com/mozilla/gecko-dev/blob/master/dom/security/nsCSPParser.cpp), [WebKit directive parsing](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/page/csp/ContentSecurityPolicyDirectiveList.cpp), and [Blink directive-value validation](https://github.com/chromium/chromium/blob/main/services/network/public/cpp/content_security_policy/content_security_policy.cc).

**Takeaway**: **Validate the container before interpreting its pieces; a convenient language whitespace predicate may implement a different grammar.**
