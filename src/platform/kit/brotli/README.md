# Brotli

Upstream: https://github.com/google/brotli
Version: **v1.2.0**, commit **028fb5a23661f123017c060daa546b55cf4bde29**.
Licence: MIT (unmodified upstream text in LICENSE).

Following Crane's nghttp2 vendoring, build.zig.zon pins the source package by
content hash. build.zig compiles only c/common, c/dec and c/enc; no tools or test
corpus is copied into this repository. Source is unchanged. The header and
library always come from the same package.

The testing, Darwin (including iOS) and Linux platforms use this implementation.
The streaming interface exposes consumed and produced bytes, complete/error
status, and allocator callbacks. This gives identical error and trailing-data
semantics and observable allocation failures on every platform, without a new
minimum OS deployment requirement. System-library selection can replace the
implementation when the same contract is verified.

RFC 7932 only: large-window mode and custom dictionaries remain disabled.
Compression §3 rejects non-RFC7932 blocks; the tentative large-window test
tracks the still-open https://github.com/whatwg/compression/issues/84.

The encoder is built with `BROTLI_ENCODER_CLEANUP_ON_OOM=1`: upstream otherwise
terminates the process on allocation failure. Allocation-failure tests cover
both encoder and decoder with the caller-provided allocator.
