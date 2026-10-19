# Spec Compliance: Navigation shares the data URL processor

**Date**: 2026-10-19

**Lesson**: A navigation URL and its decoded data body have different fragment requirements, but navigation and Fetch need one body decoder.

**Why**: Fetch's data URL processor serializes with the fragment excluded before locating the comma or decoding bytes. The complete URL still supplies navigation's fragment target.

**What Happened**: Fetch's processor omitted fragment exclusion, and navigation had a second hand-written decoder with the same omission. The upstream `url/data-uri-fragment.html` already matched `:target`, but its body incorrectly ended with `#foo`. A base64 body with a fragment also failed decoding.

**Fix**: Exclude the literal fragment delimiter in the shared processor before parsing metadata or percent-decoding. Have navigation call that processor and take its owned MIME/body slices, while retaining its full final URL. Native tests cover escaped hashes, queries, base64, a comma that occurs only in the fragment, and allocation-failure cleanup.

The rule is [Fetch's data URL processor, step 2](https://fetch.spec.whatwg.org/#data-url-processor). WebKit's [DataURLDecoder::DecodeTask::process](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/platform/network/DataURLDecoder.cpp) also separates the fragment from the encoded body before decoding it.

**Takeaway**: **Keep URL identity separate from body decoding, and share the decoder across callers.**
