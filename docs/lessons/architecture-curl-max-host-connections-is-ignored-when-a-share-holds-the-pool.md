# Architecture: curl's per-host connection limit is ignored when a share holds the pool

**Date**: 2026-10-31
**Lesson**: `CURLMOPT_MAX_HOST_CONNECTIONS` (and `CURLMOPT_MAX_TOTAL_CONNECTIONS`) do nothing for transfers whose connections live in a curl share (`CURL_LOCK_DATA_CONNECT`): the limit is read from the multi handle of the share's own admin handle, which has none. A Browser-wide connection limit over a shared pool has to be Crane's own.

**Why**: curl 8.15 and 8.18, `lib/conncache.c`, `Curl_cpool_check_limits`:

```c
  struct cpool *cpool = cpool_get_instance(data);
  ...
  if(cpool->idata->multi) {
    dest_limit = cpool->idata->multi->max_host_connections;
    total_limit = cpool->idata->multi->max_total_connections;
  }
  if(!dest_limit && !total_limit)
    return CPOOL_LIMIT_OK;
```

For a shared pool `cpool_get_instance` returns the share's cpool, initialised in `lib/curl_share.c` with the share's admin handle (`share->admin = curl_easy_init(); ... Curl_cpool_init(&share->cpool, share->admin, share, 103);`). That handle belongs to no multi, so both limits are 0 and every check passes, whatever the transfer's own multi says. And a transfer curl does hold back (`MSTATE_PENDING`) is woken by `process_pending_handles` of its own multi only - a connection freed by another agent's multi would not wake it.

**What Happened**: Lane flaky4 traced xhr/send-redirect.htm's sweep-only failures ("expected GET got null" - a network error) to wpt serve resetting connections: 35 of 150 runs failed with six runner processes at once (curl 56 "Connection reset by peer", 55 "Broken pipe", 8 "Invalid status line"). A Python client with no Crane in it reproduced the resets against the same server with unlimited parallel connections and had none at six per host. Every browser opens at most six HTTP/1.x connections per host; Crane opened one per request, 34 for that file. The obvious fix, `curl_multi_setopt(multi, CURLMOPT_MAX_HOST_CONNECTIONS, 6)` on each agent's multi handle, would have been silently inert, because every transfer of a Browser joins its NetworkContext's share.

**Fix**: `NetworkContext.ConnectionSlots` (src/fetch/network/network_context.zig): six slots per scheme://host:port, Browser-wide under the context's mutex; `NetworkScheduler` takes one before adding a transfer to its multi handle, queues the transfer in order without one, starts queued transfers from `pump` as slots free (any agent's), and gives the slot back at finalize and cancel. A destination that answered over HTTP/2 takes no slots. The wait is carried on the response (`queue_wait_ms`) so Resource Timing shows it before domainLookupStart.

**Takeaway**: **A library option is a claim about the library's data structure: when the pool is shared, check whose handle the limit is read from before relying on it - here, nobody's.**
