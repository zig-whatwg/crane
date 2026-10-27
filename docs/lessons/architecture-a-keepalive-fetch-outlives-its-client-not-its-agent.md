# Architecture: A keepalive fetch outlives its client, not its agent

**Date**: 2026-10-27
**Lesson**: A request that must survive its document is not given a longer-lived client. Its client is taken away (it is KEPT), and it runs on the agent's network side until it is over, it hits a time bound, or the agent ends.

**Why**: Fetch 2.4 "when a fetch group is terminated" step 1 terminates only the records whose request's keepalive is false. A beacon, a `fetch({keepalive: true})` and fetchLater()'s deferred sends must reach the network after their realm retires. Everything that ties a fetch to its document hangs off its client: the promise, the observers, the CSP, timing and SRI reporters, the traversable for prompts.

**What Happened**: Lane keepalive (2026-10-10) built `dom.keepalive_fetch` and deliberately terminated its dispatches when the realm retired. The handoff gave the reason that the request's reporters "name the global unguarded", and the proposed fix was an agent-level owner plus Guarded reporters in the request. Lane keepalive2 read the code first and found two things:
- **The reporters were already guarded.** Since lane winslot1 the client reporters (`csp_violations.reporterFor`, `performance_timeline.timingReporterFor`, `sri_reporting.reporterFor`) are keyed by the REALM and resolve the global at use. A retired realm answers nothing, and its ContextData stays a valid, inert record until its agent ends (`retireEntry`).
- **The real gaps were in AgentFetches.** `AgentFetches.sweep` terminated keepalive fetches too, and `AgentFetches.deinit` left any fetch still live (leaked) rather than ending it.

The visible effect: a beacon from a removed frame died whenever the collector took the frame's detached realm, and every keepalive request died at a top-level navigation.

All three engines solve it the same way, by detaching the load from its client:
- **WebKit.** NetworkResourceLoader::abort keeps a keepalive load with no response yet (`m_isKeptAlive`, `transferKeptAliveLoad` to the session) and ignores its response. ~NetworkSession aborts the kept loads.
- **Chromium.** KeepAliveURLLoader belongs to its storage partition's service and drops the response once the renderer is gone. It is deleted 30 s after the disconnection.
- **Gecko.** The parent-process FetchService spares a keepalive request on a non-forced cancel.

**Fix**:
1. `AsyncFetch.keep(now)`:
   - the client becomes a static keeper, whose `done` frees the outcome;
   - `reporting` is set to false;
   - the request's reporters are nulled, its traversable becomes no-traversable, and `process_response` is nulled.
2. `AgentFetches.sweep`:
   - A gone client whose `request.keepalive and !delivered` is kept, and still hears `gone`. Clients are unchanged: Dispatch and FetchCall free themselves as before.
   - A kept fetch older than `kept_limit_ms` (30 s, Chromium's engine resource bound, not a compatibility ruling) is terminated.
3. `AgentFetches.deinit` terminates the kept fetches. They reach no client and no realm, so no engine is needed.
4. fetchLater's records are sent as fetches kept from the start (`keepalive_fetch.startKept`). This happens from an unloading document cleanup step, and from a back/forward-cache store step.

Red tests: tests/html/ka2_kept_fetch_test.zig. On main, 4 of its 5 tests failed: the request never reached the loopback server, because the sweep cancelled it before the network was pumped.

**Takeaway**: **Before giving a request a longer-lived owner, check what its client links actually reach. Here they were realm-keyed already, so the fix was to stop the sweep from terminating keepalive fetches and to end kept fetches at the agent's end. Keep the fetch, drop the client, bound the lifetime by the owner that pumps it.**
