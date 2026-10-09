# Spec Compliance: A host test backend fixes only the files whose types it decodes

**Date**: 2026-10-09
**Lesson**: The browsers-first audit grouped 14 files as "blocked because Crane has no decoder" (12 mixed-content audio-tag files and CSP media-src-7_1_2 and 7_2_2). The WPT runner's WAV test backend moves the 12 - they use `<source type="audio/wav">` - and cannot move the other two: their sources are `type="video/webm"` and `type="audio/webm"`.

**Why**: Resource selection's children steps refuse a `<source>` whose type the user agent knows it cannot render before any fetch (HTML 4.8.11.5, children step 6). A backend that answers canPlayType only for what it really decodes (the user's ruling, 2026-10-08: "Host decoders only"; never fake support) answers "" for webm, so the webm source is still refused, the CSP check never runs, and the second securitypolicyviolation that media-src-7_x_2's third subtest waits for never fires.

**What Happened**: Read before building: the two CSP files do not go through common.sub.js's requestViaAudio, which is what the audit's "every audio request is a `<source type=audio/wav>`" described. Reported to the integrator before item 1; they stay TIMEOUT 2/3 and need a host backend that decodes webm (VP8/Vorbis/Opus).

**Fix**: The WAV backend (tests/wpt_runner/wav_backend.zig) answers "maybe" for audio/wav, audio/wave and audio/x-wav, "probably" with codecs="1", "" for everything else - including the WAV codecs Gecko accepts but it does not decode ("3", "6", "7"). Count each target file's `<source type>` before promising its gain.

**Takeaway**: **Before claiming a capability fixes a group of files, read each file's own media types: a typed source the backend cannot decode is refused before fetch, whatever the group's label says.**
