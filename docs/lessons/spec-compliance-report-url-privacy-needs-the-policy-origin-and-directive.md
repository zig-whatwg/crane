# Spec Compliance: Report URL privacy needs the policy origin and directive

**Date**: 2026-10-09
**Lesson**: A CSP report's blocked URL cannot be sanitized correctly without its effective directive and reporting origin.

**Why**: The cached CSP §5.4 strips credentials and fragments. Shipping browsers additionally hide the path and query of cross-origin frame-src and object-src resources. A context-free URL formatter cannot distinguish that case from an image URL or a same-origin frame.

**What Happened**: Crane passed only the resource URL to its violation formatter. The frame-src-blocked-path-matching WPT passed 1/3, while aligned stable Chrome, Firefox and Safari each passed 3/3 at revision cc74d2669f (run IDs 6218298311311360, 4877098740350976 and 5164107446878208). Both failures exposed a cross-origin path where the test expected the origin.

**Fix**: Pass the effective directive and the settings object's origin to the formatter. Compare tuple origins with normalized default ports, keep same-origin paths, and reduce cross-origin frame/object URLs to origins. Use the settings origin rather than the document URL: about:blank and srcdoc can inherit an origin, and a sandboxed document can have an opaque origin. The engine reference is Blink's [ContentSecurityPolicy::StripURLForUseInReport](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/frame/csp/content_security_policy.cc), including its crbug.com/633306 rationale. The allocator-backed test covers opaque origins, IPv6, credentials, port differences and unrelated directives.

**Takeaway**: **Preserve the context a browser privacy rule depends on; a URL alone is not always enough.**
