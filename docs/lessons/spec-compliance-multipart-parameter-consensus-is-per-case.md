# Spec Compliance: Multipart parameter consensus is per case

**Date**: 2026-10-11
**Lesson**: A multipart header's browser behavior cannot be obtained by adopting one engine's entire parameter parser.

**Why**: Blink, WebKit and Gecko disagree on different parts of Content-Disposition parsing. Blink and WebKit keep semicolons inside quotes; WebKit and Gecko preserve ordinary backslashes and require lowercase parameter names; Blink and Gecko take the last duplicate and recognize quoted values after optional whitespace following `=`.

**What Happened**: Crane found `name=` by substring, so it could use the suffix of `filename=` as the field name. It ignored unquoted values, making the upstream multipart Blob-to-formData test fail even though all three browsers passed that subtest. Reading the three engines also exposed malformed and escaped-value cases with separate majorities or three-way splits.

**Fix**: Scan delimited parameters, preserve quoted data, and allocate only the selected name and filename. Record the source-backed ruling for each deviation, with native regressions and allocation-failure coverage. Escaped quotes and missing separators after a closed quote follow RFC 2183/RFC 822 when the browser results split three ways. Preserve existing disposition-type handling separately from the parameter change.

**Takeaway**: **Compare engines per input case; a majority for one part of a parser does not establish a majority for the rest.**

Evidence: [Blink parameter parser](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/platform/network/parsed_content_header_field_parameters.cc), [Blink tokenizer](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/platform/network/header_field_tokenizer.cc), [WebKit parseParameters](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/Modules/fetch/FetchBodyConsumer.cpp), [Gecko FormDataParser](https://searchfox.org/mozilla-central/source/dom/base/BodyUtil.cpp), [RFC 2183](https://www.rfc-editor.org/rfc/rfc2183), [RFC 822](https://www.rfc-editor.org/rfc/rfc822).
