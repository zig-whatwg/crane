# Spec Compliance: Check broken sniffing arithmetic against an engine

**Date**: 2026-10-11
**Lesson**: An error in a specification's arithmetic calls for engine evidence and byte-vector tests, not removal of the affected validation.

**Why**: MP3 frame lengths depend on the MPEG version, bitrate table, sample-rate reduction and scale together. A plausible formula can point at bytes inside a frame instead of the next header.

**What Happened**: Crane's sniffer followed reversed table/scale prose and skipped Layer III validation because another expression in the standard was malformed. The upstream WPT MP3 vector begins FFFB50C4, whose next frame is 208 bytes away; the old formula jumped 130 bytes. Its second-header check could also read past a truncated input.

**Fix**: Read Gecko's [mp3_parse, mp3_framesize, is_mp3 and mp3_sniff](https://github.com/mozilla/gecko-dev/blob/master/toolkit/components/mediasniffer/mp3sniff.c). With the integrator's browser-rule ruling, use its table selection, sample-rate reduction, scale, padding, Layer III restriction and complete-second-header bound. Preserve its acceptance of reserved version 1. The specification defects are tracked in [MIME Sniffing #70](https://github.com/whatwg/mimesniff/issues/70) and [#168](https://github.com/whatwg/mimesniff/issues/168). Test the actual WPT vectors and synthetic MPEG1/2/2.5 frame boundaries independently of media playback.

**Takeaway**: **A signature test proves classification; it cannot prove playback when the host has no decoder.**
