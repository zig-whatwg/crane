# Spec Compliance: MIME parsing does not validate a multipart boundary

**Date**: 2026-10-11
**Lesson**: Replacing an ad hoc header parser with a MIME record must preserve the consumer's boundary validation.

**Why**: A quoted MIME parameter may be empty, while RFC 2046 section 5.1.1 requires a multipart boundary to contain at least one character.

**What Happened**: Fetch's formData() began taking the boundary from the parsed MIME record. The old boundary extractor rejected an empty string, but the new call site passed it through. The multipart parser then treated `--` as the delimiter: `----` became an empty form and a crafted part body also parsed successfully.

**Fix**: Reject the empty boundary with TypeError before calling the multipart parser, matching Blink's Body::formData guard. A native browser test using std.testing.allocator and a Crane fixture cover both confusing bodies, empty/null bodies, and a valid nonempty boundary with zero parts.

**Takeaway**: **Validate a parsed parameter against its consumer's grammar before using it as a delimiter.**

Evidence: [RFC 2046 section 5.1.1](https://www.rfc-editor.org/rfc/rfc2046#section-5.1.1), [Blink Body::formData](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/fetch/body.cc).
