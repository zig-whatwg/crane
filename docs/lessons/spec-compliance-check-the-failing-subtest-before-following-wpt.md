# Spec Compliance: Check the failing subtest before following WPT

**Date**: 2026-10-11
**Lesson**: A test file's name and aggregate pass count do not establish browser behavior for an individual assertion.

**Why**: A shared empty-body shortcut can conceal an encoder defect. Tightening the consumer's MIME validation exposes the defect even though the consumer is following the browsers.

**What Happened**: Empty FormData encoded to zero bytes, with a comment claiming that every browser did this. At aligned wpt.fyi revision cc74d2669f, Chrome, Firefox and Safari each passed body/formdata.any.html 3/3, including empty round trips. They each passed request-consume-empty.any.html and response-consume-empty.any.html 13/14: the sole failure was the assertion that an empty FormData encodes to zero bytes. Blink's FormData::EncodeMultiPartFormData appends the closing boundary unconditionally. The parser separately rejected that valid zero-part closing delimiter.

**Fix**: Emit the existing closing delimiter even with zero entries. Accept that delimiter before skipping its CRLF in the parser; keep a raw empty body or truncated opening invalid. Record the zero-length assertions as intentional losses matching all three browsers, and test encoding, parsing and round trips independently.

**Takeaway**: **Read the per-subtest result and the engine's actual algorithm before treating a WPT assertion as browser consensus.**

Evidence: [round trips](https://wpt.fyi/results/fetch/api/body/formdata.any.html?sha=cc74d2669f), [empty response](https://wpt.fyi/results/fetch/api/response/response-consume-empty.any.html?sha=cc74d2669f), [empty request](https://wpt.fyi/results/fetch/api/request/request-consume-empty.any.html?sha=cc74d2669f), [Blink FormData encoding](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/html/forms/form_data.cc).
