# Architecture: Single-threaded networking must send the request before the script ends, and let the timer decide timeouts

**Date**: 2026-09-25
**Lesson**: A transfer added to the curl multi handle does not leave until the next pump. And a timeout measured when the completion task runs includes whatever long task delayed it.

**Why**: Crane has no network thread. A non-blocking connect needs a socket wait and a second `curl_multi_perform`: a 0 ms `multi_poll` did not complete it, and a 1 ms one did.

**Fix**: `NetworkScheduler.start` pushes the transfer forward: perform, wait at most 1 ms, up to 4 rounds, stopping once `CURLINFO_REQUEST_SIZE` > 0. For async requests the timeout timer is authoritative, and it gives the network one step before timing out.

**Takeaway**: **"In parallel" in a spec means the network makes progress while script runs. Emulate that at the edges: send at start, and read the socket before declaring a timeout.**
