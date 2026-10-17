# Spec Compliance: A fatal decode drops input, not handler mode

**Date**: 2026-10-16
**Lesson**: Distinguish a decoder's mode from bytes retained only to replay malformed input. Replacement mode needs the replay bytes; a fatal TextDecoder call discards them under Crane's browser-majority rule.

**Why**: A raw decoder reports an error to several callers. Resetting the whole decoder destroys ISO-2022-JP's Roman or Katakana mode, while retaining its complete replay state can expose input from a failed call. The Encoding Standard's persistent queue and browser implementations differ here.

**What Happened**: The WPT `fatal stream: utf-8` case proves that all three browsers discard an unread suffix after a fatal error; it does not prove what happens to restored CJK bytes. Source inspection of `81 30 81 2B`, followed by `40`, predicts three different results: Blink `+@`, Gecko `0丂`, WebKit `@`. These are source-derived predictions, not measured browser results. Per component, however, WebKit and Gecko drop the current restored byte; Blink and WebKit process the older restored digit/lead during the failing call, losing them with its output. Both majorities therefore match WebKit's complete behavior. The integrator ruled to use that combination, rather than the spec's repeated error, which none implements.

**Fix**: At TextDecoder's fatal error boundary, discard only restored input: gb18030's pending digit and retained restored lead, ISO-2022-JP's prepended bytes, and UTF-16's restored leading byte. Keep handler mode. Raw replacement callers never perform this discard. Test the raw decoder and the generated TextDecoder interface, with current-chunk and previous-chunk prefixes, UTF-16 pushback, UTF-8 unread input, and ISO mode survival.

**Evidence**: WPT revision `cc74d2669f`, `encoding/textdecoder-mistakes.any.html`, `fatal stream: utf-8` and `fatal stream: iso-2022-jp`; [Blink Decoder::Decode and Gb18030Decoder::ParseByte](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/platform/wtf/text/text_codec_cjk.cc); [Gecko TextDecoder::DecodeNative](https://github.com/mozilla-firefox/firefox/blob/main/dom/encoding/TextDecoder.cpp) and [encoding_rs's pending_ascii/unread handling](https://github.com/hsivonen/encoding_rs/blob/master/src/gb18030.rs); [WebKit decodeCommon](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/PAL/pal/text/TextCodecCJK.cpp).

**Takeaway**: **When whole browser outcomes split three ways, inspect each relevant mechanism. Use the component majorities only if their combination matches a shipping browser; otherwise use the spec. Never generalize one passing UTF-8 test into a claim about every codec's restored queue.**
