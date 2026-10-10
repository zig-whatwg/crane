# Spec Compliance: A keepalive quota is a running total, and ping loads are exempt

**Date**: 2026-10-10
**Lesson**: Count a fetch group's in-flight keepalive bytes as a running total, reserved when a request starts and released once when it ends. Before applying the quota to every keepalive request, check which loads each engine actually counts.

**Why**: Fetch's HTTP-network-or-cache fetch step 8.10 sums the body lengths of the fetch group's in-flight keepalive records, adds the new request's own length, and fails above 64 KiB. Taken literally this counts the request twice: "fetch" step 16 has already appended its record to the group, so a body of exactly 64 KiB would fail. WPT expects it to pass (fetch/api/request/request-keepalive-quota.html, where Chrome and Firefox pass 6/6). The spec also covers every keepalive request that has a client. The engines only apply it to some of them.

**What Happened**: The keepalive lane (2026-10-10) added the 64 KiB budget behind fetch({keepalive}) and the shared dispatch that sendBeacon will use. Its first plan counted legacy CSP reports, because CSP sets keepalive on them and Fetch counts every keepalive request. The integrator asked for the engines to be checked before pings were left out. That check found:
- **Blink counts everything with a body.** ResourceFetcher::StartLoad reserves into `inflight_keepalive_bytes_`, and HandleLoaderFinish / HandleLoaderError release it. PingLoader sends pings and CSP reports through the same ResourceFetcher.
- **WebKit skips ping loads.** KeepaliveRequestTracker::tryRegisterRequest is called from CachedResource::load only when `type() != Type::Ping`, and PingLoader::startPingLoad makes CSP reports and pings Ping resources.
- **Gecko skips them too.** FetchUtil::IncrementPendingKeepaliveRequestSize, which keeps the load group's total, has one caller: dom/fetch/Fetch.cpp. Pings and CSP reports open channels directly.

So the majority (2-1) exempts ping loads, and golden rule 2 decides it.

**Fix**:
1. `dom.document_fetches.FetchGroup`: a running `inflight_keepalive_bytes`, with `reserveKeepalive(length)` (fails when `length > quota - in_flight`, which cannot overflow) and `releaseKeepalive`. Each global owns one, reached through `global_settings.fetchGroupOf`.
2. `dom.keepalive_fetch.Reservation.take(global, request, load)` reserves when the request starts. It returns null when there is nothing to hold: not keepalive, not HTTP(S), no body or an empty one, or `load == .ping`. Its holder releases it once, through a slab-generation link to the global, so a request that outlives its global touches nothing.
3. fetch() releases on every way a fetch can end (finished, gone, signal abort, document abort, failed start), plus once more as a last resort when the call is freed. The release is idempotent: the field is nulled on the first release.

**Takeaway**: **A quota "summed over in-flight records" that include the request being checked double-counts it: implement the engines' running total, reserved at start and released once at the end. Then check which load types each engine actually counts before applying a spec rule to every request that carries the flag.**
