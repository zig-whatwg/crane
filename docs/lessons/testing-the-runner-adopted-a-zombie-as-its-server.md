# Testing: The runner adopted a zombie as its server, because a zombie answers `kill(pid, 0)`

**Date**: 2026-09-22
**Lesson**: `checkExistingServer` decided "a server is running" by probing the
lockfile's pid with signal 0. A `<defunct>` process passes that probe.

**What Happened**: a runner spawned `wpt serve` while another process already
held :8000. The child died at bind, its parent never reaped it - it was blocked
in `wait4` on a different child - and it had already written
`.wpt_serve.lock` with its pid. From then on every runner "adopted" pid 49683,
a zombie, as the server. It was harmless only because an unrelated `wpt serve`
(53135) happened to be serving the port. Whenever it was not, a run reported

    Page load error: error.NetworkError    (0ms)

with no curl diagnostic - curl never ran, there was nothing to connect to. Eight
of twelve files in one timers run went that way, and the same signature turned
up standalone.

**Fix**: adopt by probing the PORT with a TCP connect (`isServerReady`), which is
the question the code was actually asking; keep the lockfile's pid only if it is
a live, non-zombie process, otherwise adopt with no pid. A lockfile whose port
does not answer is stale whatever its pid says.

**Takeaway**: **"The process exists" and "the process is doing its job" are
different claims, and a zombie satisfies only the first.** Probe the resource,
not the pid. Seventh way this harness manufactures a result.
