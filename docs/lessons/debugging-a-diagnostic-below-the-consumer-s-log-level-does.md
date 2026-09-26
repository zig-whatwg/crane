# Debugging: A diagnostic below the consumer's log level does not exist

**Date**: 2026-09-21
**Lesson**: Every curl diagnostic was `log.debug`; the WPT runner runs at `.warn`.

**What Happened**: A hard transport failure — connection refused, TLS
handshake failure, DNS failure — printed **nothing at all**. Diagnosing the
mbedTLS ABI mismatch took a 2,052-file journal analysis and four independent
experiments. With the error visible it would have taken one run: curl's own
message named it outright.

**Fix**: Transport failures log at `warn` with the curl code and
`CURLOPT_ERRORBUFFER` text. Per-request chatter stays `debug`. Note
`CURLOPT_ERRORBUFFER` was not even declared in the FFI, and
`curl_easy_strerror` is not a substitute — it gives "Couldn't connect to
server" where the error buffer gives the host, port and timing.

**Takeaway**: **Pick the level from the consumer's threshold, not the
author's.** A failure nobody can see costs more than the noise of one they can.
