//! The Update algorithm's step 7 (Service Workers Appendix A): the script
//! fetch with its fetch hook's checks - the MIME type, the maximum scope
//! (`Service-Worker-Allowed`) - and the byte-for-byte comparison of the main
//! script and, when it is unchanged, of every imported script, which decides
//! hasUpdatedResources. Run on the job thread with the registry's lock not
//! held; what it fetches comes from a Fetcher (Fetch in a Browser, a table
//! in the tests).
//!
//! Stated deviations:
//! - A response whose status is not an ok status is a network error before
//!   its MIME type is looked at (a TypeError, not step 7's SecurityError):
//!   the browsers check the status first - Chromium's
//!   ServiceWorkerNewScriptLoader fails on the response code before the MIME
//!   check - and WPT registration-tests-script.js "Registering non-existent
//!   script" expects a TypeError for a 404 served as text/html.
//! - An imported script whose fetch is a network error is left out of the
//!   updated resource map (step 21.5 stores the network error; a worker that
//!   then imports it gets a network error either way).
//! - A module script's imports are not compared: only its root is fetched
//!   here (its graph is fetched by the worker's realm when it runs).
//!
//! Spec: https://w3c.github.io/ServiceWorker/#update-algorithm

const std = @import("std");
const Allocator = std.mem.Allocator;
const html = @import("html");
const html_core = @import("html_core");
const fetch = @import("fetch");
const registry_mod = @import("registry.zig");
const scope_mod = @import("scope.zig");

const script_fetch = html_core.workers.script_fetch;
const Resource = script_fetch.ServiceWorkerResource;

/// Where the fetches go.
pub const Fetcher = struct {
    ctx: *anyopaque,
    /// One script resource; error.NetworkError for a network error.
    fetch: *const fn (ctx: *anyopaque, allocator: Allocator, url: []const u8, kind: script_fetch.ServiceWorkerResourceKind, bypass_http_cache: bool) error{ NetworkError, OutOfMemory }!Resource,
    /// The script resource's policy container (taken), as the registry keeps
    /// it (opaque); null when it cannot.
    wrap_policy: *const fn (ctx: *anyopaque, allocator: Allocator, container: fetch.internal.PolicyContainer) ?*anyopaque,
};

/// A "bad import script response": a network error (never handed back
/// here), a status that is not an ok status, or a MIME type that is not a
/// JavaScript MIME type. (Kept in step with "fetch a classic worker-imported
/// script".)
pub fn isBadImportScriptResponse(response: *const Resource) bool {
    if (response.status < 200 or response.status > 299) return true;
    return !html.module_script.isJavaScriptMimeType(response.content_type);
}

/// Update step 7, and the fetch hook's steps 7-22, for `plan`: what the
/// registry resumes with (`Registry.updateFetched`).
pub fn run(allocator: Allocator, plan: *const registry_mod.FetchPlan, fetcher: Fetcher) registry_mod.FetchOutcome {
    return runFallible(allocator, plan, fetcher) catch .{ .failure = .network };
}

fn runFallible(allocator: Allocator, plan: *const registry_mod.FetchPlan, fetcher: Fetcher) Allocator.Error!registry_mod.FetchOutcome {
    var outcome: registry_mod.FetchOutcome = .{};
    errdefer {
        for (outcome.resources.items) |*r| r.deinit(allocator);
        outcome.resources.deinit(allocator);
    }
    // "Fetch a classic worker script" (or a module graph's root) with the
    // fetch hook's steps 1-6: no-cache per step 2.
    var response = fetcher.fetch(fetcher.ctx, allocator, plan.script_url, .main_script, plan.bypass_http_cache) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.NetworkError => return .{ .failure = .network },
    };
    defer response.deinit();
    // Not an ok status: a network error (see the file's deviations).
    if (response.status < 200 or response.status > 299) return .{ .failure = .network };
    // 7. Not a JavaScript MIME type: Reject Job Promise with a
    // "SecurityError", and a network error.
    if (!html.module_script.isJavaScriptMimeType(response.content_type)) return .{ .failure = .security };
    // 8-16. The maximum scope: a header that does not parse is a network
    // error; a scope outside it a "SecurityError".
    const allowed = scope_mod.scopeIsAllowed(allocator, plan.script_url, plan.scope_url, response.service_worker_allowed) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.NetworkError => return .{ .failure = .network },
    };
    if (!allowed) return .{ .failure = .security };
    // 10. policyContainer, from the response - handed over at the end.
    var policy = response.takePolicyContainer();
    errdefer if (policy) |*container| container.deinit();
    // 17-18. updatedResourceMap[url] = response.
    try outcome.resources.append(allocator, try resourceOf(allocator, plan.script_url, &response));
    // 19. A response not from the local cache: the last update check time.
    if (response.from_network) outcome.checked_network = true;

    // 20. hasUpdatedResources: no newest worker, another script url or type,
    // or another body.
    const newest = plan.newest orelse {
        outcome.has_updated_resources = true;
        return finish(allocator, &outcome, &policy, fetcher);
    };
    if (!std.mem.eql(u8, newest.script_url, plan.script_url) or newest.worker_type != plan.worker_type) {
        outcome.has_updated_resources = true;
        return finish(allocator, &outcome, &policy, fetcher);
    }
    const stored_main = storedResource(newest.resources, plan.script_url);
    if (stored_main == null or !std.mem.eql(u8, stored_main.?.body, response.body)) {
        outcome.has_updated_resources = true;
        return finish(allocator, &outcome, &policy, fetcher);
    }
    // 21. Unchanged main script, and classic scripts were imported: each
    // imported script is fetched again and compared - every one, so the
    // map is complete.
    if (newest.classic_scripts_imported) {
        for (newest.resources) |stored| {
            // 21.1.1. Not the main script.
            if (std.mem.eql(u8, stored.url, plan.script_url)) continue;
            // 21.1.2-4. A request with no-cache per 21.3.
            var fetched = fetcher.fetch(fetcher.ctx, allocator, stored.url, .imported_script, plan.bypass_http_cache_for_imports) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                error.NetworkError => continue,
            };
            defer fetched.deinit();
            // 21.1.5. updatedResourceMap[importUrl] = fetchedResponse.
            try outcome.resources.append(allocator, try resourceOf(allocator, stored.url, &fetched));
            // 21.1.7. The last update check time.
            if (fetched.from_network) outcome.checked_network = true;
            // 21.1.8. A bad response is ignored for the comparison.
            if (isBadImportScriptResponse(&fetched)) continue;
            // 21.1.9. Another body: updated (the loop goes on).
            if (!std.mem.eql(u8, fetched.body, stored.body)) outcome.has_updated_resources = true;
        }
    }
    // 22. Complete with the response.
    return finish(allocator, &outcome, &policy, fetcher);
}

/// The outcome, with the script resource's policy container handed to the
/// registry's keeping.
fn finish(allocator: Allocator, outcome: *registry_mod.FetchOutcome, policy: *?fetch.internal.PolicyContainer, fetcher: Fetcher) registry_mod.FetchOutcome {
    if (policy.*) |container| outcome.policy = fetcher.wrap_policy(fetcher.ctx, allocator, container);
    policy.* = null;
    return outcome.*;
}

fn storedResource(resources: []const registry_mod.Resource, url: []const u8) ?*const registry_mod.Resource {
    for (resources) |*r| if (std.mem.eql(u8, r.url, url)) return r;
    return null;
}

fn resourceOf(allocator: Allocator, url: []const u8, response: *const Resource) Allocator.Error!registry_mod.Resource {
    const owned_url = try allocator.dupe(u8, url);
    errdefer allocator.free(owned_url);
    const body = try allocator.dupe(u8, response.body);
    errdefer allocator.free(body);
    return .{ .url = owned_url, .body = body, .content_type = try allocator.dupe(u8, response.content_type) };
}
