//! A Browser's Clear-Site-Data handler: what a response's `Clear-Site-Data`
//! header clears of this Browser's state (Clear Site Data 4.2 steps 4-6).
//!
//! Fetch parses the header and finds the origin (fetch.algorithms.
//! clear_site_data); it reaches this handler through the request's network
//! context, where Browser.init installed it before any realm existed
//! (`clearerFor`). Chromium's shape: the network service hands the header to
//! the browser (NetworkContextClient::OnClearSiteData), whose
//! ClearSiteDataHandler and BrowsingDataRemover clear each storage
//! (content/browser/browsing_data/clear_site_data_handler.cc,
//! clear_site_data_utils.cc).
//!
//! It runs on the fetching thread - a window's, a worker's, the service
//! worker job thread's - before the response is handed on. Each storage is
//! cleared under its own lock, and what a realm must see is queued as a task
//! of that realm: nothing here runs script or touches a realm.
//!
//! Spec: https://w3c.github.io/webappsec-clear-site-data/#clear-response

const std = @import("std");
const runtime = @import("runtime");
const fetch = @import("fetch");
const service_worker = @import("service_worker");

const Types = fetch.algorithms.clear_site_data.Types;
const SiteDataClearer = fetch.network.NetworkContext.SiteDataClearer;

const log = std.log.scoped(.clear_site_data);

/// The clearer for the Browser whose scope is `scope` (BORROWED: the scope
/// outlives every fetch of the Browser).
pub fn clearerFor(scope: *runtime.BrowserScope) SiteDataClearer {
    return .{ .context = scope, .clear = clear };
}

/// 4.2 steps 4-6 for `origin` (serialized) and `types`.
fn clear(context: *anyopaque, origin: []const u8, types: Types) void {
    const scope: *runtime.BrowserScope = @ptrCast(@alignCast(context));
    log.debug("Clear-Site-Data for {s}: cache={} cookies={} storage={} executionContexts={} clientHints={}", .{
        origin, types.cache, types.cookies, types.storage, types.execution_contexts, types.client_hints,
    });

    // 4. "Prepare to clear origin's data" (4.2.1): with
    // "executionContexts", every browsing context whose active document's
    // origin is `origin` gets an empty sandboxing directive parsed into its
    // active sandboxing flag set, so it cannot recreate what is cleared.
    // TODO(Clear-Site-Data executionContexts): the browsing contexts of
    // the Browser's navigables, sandboxed here; the list then reloads in
    // step 6.

    // 5. Each type.
    if (types.cache) {
        // 4.2.3 "clear cache for origin": the spec removes every network
        // cache entry whose target URI's host is the origin's host - any
        // scheme or port. Chrome and Safari clear the exact origin instead:
        // Chromium's SiteDataClearer adds the origin to the cache's filter
        // (clear_site_data_utils.cc, `AddOrigin(origin_)`, a URL filter over
        // every partition), WebKit's processClearSiteDataHeader removes
        // DiskCache and MemoryCache for a ClientOrigin whose origin is the
        // response URL's (NetworkResourceLoader.cpp). Golden rule 2: the two
        // shipping browsers agree, no newer spec text - the exact origin, in
        // every partition of the Browser's HTTP cache.
        // TODO(Clear-Site-Data cache): the CORS-preflight cache's entries
        // (NetworkContext.preflight_cache) and any script or module cache
        // keyed by the origin.
        if (scope.existing(fetch.network.NetworkContext)) |network| {
            if (network.http_cache) |http_cache| http_cache.clearOrigin(origin);
        }
    }
    if (types.cookies) {
        // 4.2.4 "clear cookies for origin": every cookie in the jar whose
        // domain domain-matches the registered domain of the origin's host
        // (the host itself for an IP address or a host with no registered
        // domain, as Chrome does), with the CookieStore change events that
        // removal fires; then the authentication entries
        // (NetworkContext.auth_entries) of origins of that registered
        // domain. TODO(Clear-Site-Data cookies): the jar has no
        // registered-domain removal yet (src/cookiestore).
    }
    if (types.storage) {
        // 4.2.5 "clear DOM-accessible storage for origin".
        // 4. Every service worker registration whose scope URL's origin is
        // `origin`: unregistered - at once, as Chrome and Safari do
        // (Registry.clearOrigin says why).
        if (scope.existing(service_worker.Manager)) |manager| manager.clearOrigin(origin);
        // TODO(Clear-Site-Data storage): 1-2. clear() on the origin's
        // localStorage and sessionStorage areas (with their storage events'
        // rules); 3. delete each of the origin's IndexedDB databases; 6.
        // the origin's other script-accessible storage - Cache Storage, the
        // origin private file system (Chrome's DATA_TYPE_DOM_STORAGE, WebKit's
        // LocalStorage, SessionStorage, IndexedDBDatabases, DOMCache,
        // FileSystem).
    }
    if (types.client_hints) {
        // Empty the Accept-CH cache[origin]. TODO(Clear-Site-Data
        // clientHints): Crane keeps no Accept-CH cache yet.
    }

    // 6. With "executionContexts", reload the browsing contexts step 4
    // sandboxed (4.2.2: their Location's reload()). TODO(Clear-Site-Data
    // executionContexts): a navigation of each, queued on its own event
    // loop - WebKit's ReloadExecutionContextsForOrigin.
}
