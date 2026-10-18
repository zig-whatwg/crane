//! The Update algorithm's step 7 (update_fetch.zig), with a table for a
//! network: the status, MIME type and maximum-scope checks, and the
//! byte-for-byte comparison of the main script and the imported scripts that
//! decides hasUpdatedResources.

const std = @import("std");
const testing = std.testing;
const sw = @import("service_worker");
const html_core = @import("html_core");
const fetch = @import("fetch");
const registry = sw.registry;
const update_fetch = sw.update_fetch;
const script_fetch = html_core.workers.script_fetch;

const Entry = struct {
    url: []const u8,
    status: u16 = 200,
    content_type: []const u8 = "text/javascript",
    body: []const u8,
    allowed: ?[]const u8 = null,
};

/// A network that answers from `entries`; a URL it lacks is a network error.
const Table = struct {
    entries: []const Entry,
    fetched: std.ArrayListUnmanaged([]const u8) = .empty,

    fn fetcher(self: *Table) update_fetch.Fetcher {
        return .{ .ctx = self, .fetch = fetchOne, .wrap_policy = wrapPolicy };
    }

    fn fetchOne(ctx: *anyopaque, allocator: std.mem.Allocator, url: []const u8, _: script_fetch.ServiceWorkerResourceKind, _: bool) error{ NetworkError, OutOfMemory }!script_fetch.ServiceWorkerResource {
        const self: *Table = @ptrCast(@alignCast(ctx));
        self.fetched.append(testing.allocator, url) catch {};
        for (self.entries) |entry| {
            if (!std.mem.eql(u8, entry.url, url)) continue;
            return .{
                .allocator = allocator,
                .status = entry.status,
                .body = try allocator.dupe(u8, entry.body),
                .final_url = try allocator.dupe(u8, url),
                .content_type = try allocator.dupe(u8, entry.content_type),
                .service_worker_allowed = if (entry.allowed) |a| try allocator.dupe(u8, a) else null,
                .from_network = true,
            };
        }
        return error.NetworkError;
    }

    fn wrapPolicy(_: *anyopaque, _: std.mem.Allocator, container: fetch.internal.PolicyContainer) ?*anyopaque {
        var taken = container;
        taken.deinit();
        return null;
    }

    fn deinit(self: *Table) void {
        self.fetched.deinit(testing.allocator);
    }
};

fn plan(script_url: []const u8, scope_url: []const u8, newest: ?registry.FetchPlan.Newest) registry.FetchPlan {
    return .{
        .job = 1,
        .script_url = @constCast(script_url),
        .scope_url = @constCast(scope_url),
        .worker_type = .classic,
        .bypass_http_cache = true,
        .bypass_http_cache_for_imports = false,
        .fetch_client = null,
        .newest = newest,
    };
}

fn freeOutcome(outcome: *registry.FetchOutcome) void {
    for (outcome.resources.items) |*r| r.deinit(testing.allocator);
    outcome.resources.deinit(testing.allocator);
}

fn resource(url: []const u8, body: []const u8) registry.Resource {
    return .{ .url = @constCast(url), .body = @constCast(body), .content_type = @constCast("text/javascript") };
}

test "a first registration's script: fetched, checked, and updated (no newest worker)" {
    var table: Table = .{ .entries = &.{.{ .url = "https://e.com/js/sw.js", .body = "v1" }} };
    defer table.deinit();
    const p = plan("https://e.com/js/sw.js", "https://e.com/js/", null);
    var outcome = update_fetch.run(testing.allocator, &p, table.fetcher());
    defer freeOutcome(&outcome);
    try testing.expect(outcome.failure == null);
    try testing.expect(outcome.has_updated_resources);
    try testing.expect(outcome.checked_network);
    try testing.expectEqual(@as(usize, 1), outcome.resources.items.len);
    try testing.expectEqualStrings("v1", outcome.resources.items[0].body);
}

test "a status that is not ok is a network error; a MIME type that is not JavaScript, or a scope above the maximum, a SecurityError" {
    var missing: Table = .{ .entries = &.{.{ .url = "https://e.com/sw.js", .status = 404, .content_type = "text/html", .body = "nope" }} };
    defer missing.deinit();
    const p = plan("https://e.com/sw.js", "https://e.com/", null);
    var a = update_fetch.run(testing.allocator, &p, missing.fetcher());
    defer freeOutcome(&a);
    try testing.expectEqual(registry.FetchOutcome.Failure.network, a.failure.?);

    var plain: Table = .{ .entries = &.{.{ .url = "https://e.com/sw.js", .content_type = "text/plain", .body = "x" }} };
    defer plain.deinit();
    var b = update_fetch.run(testing.allocator, &p, plain.fetcher());
    defer freeOutcome(&b);
    try testing.expectEqual(registry.FetchOutcome.Failure.security, b.failure.?);

    var deep: Table = .{ .entries = &.{.{ .url = "https://e.com/js/sw.js", .body = "x" }} };
    defer deep.deinit();
    const above = plan("https://e.com/js/sw.js", "https://e.com/", null);
    var c = update_fetch.run(testing.allocator, &above, deep.fetcher());
    defer freeOutcome(&c);
    try testing.expectEqual(registry.FetchOutcome.Failure.security, c.failure.?);

    // Service-Worker-Allowed widens it; one that does not parse is a
    // network error.
    var allowed: Table = .{ .entries = &.{.{ .url = "https://e.com/js/sw.js", .body = "x", .allowed = "/" }} };
    defer allowed.deinit();
    var d = update_fetch.run(testing.allocator, &above, allowed.fetcher());
    defer freeOutcome(&d);
    try testing.expect(d.failure == null);
    var broken: Table = .{ .entries = &.{.{ .url = "https://e.com/js/sw.js", .body = "x", .allowed = "http://[" }} };
    defer broken.deinit();
    var e = update_fetch.run(testing.allocator, &above, broken.fetcher());
    defer freeOutcome(&e);
    try testing.expectEqual(registry.FetchOutcome.Failure.network, e.failure.?);
}

test "an unchanged main script is no update; another body is" {
    var resources = [_]registry.Resource{resource("https://e.com/sw.js", "v1")};
    const newest: registry.FetchPlan.Newest = .{ .script_url = @constCast("https://e.com/sw.js"), .worker_type = .classic, .classic_scripts_imported = false, .resources = &resources };
    const p = plan("https://e.com/sw.js", "https://e.com/", newest);

    var same: Table = .{ .entries = &.{.{ .url = "https://e.com/sw.js", .body = "v1" }} };
    defer same.deinit();
    var a = update_fetch.run(testing.allocator, &p, same.fetcher());
    defer freeOutcome(&a);
    try testing.expect(a.failure == null);
    try testing.expect(!a.has_updated_resources);

    var changed: Table = .{ .entries = &.{.{ .url = "https://e.com/sw.js", .body = "v2" }} };
    defer changed.deinit();
    var b = update_fetch.run(testing.allocator, &p, changed.fetcher());
    defer freeOutcome(&b);
    try testing.expect(b.has_updated_resources);
}

test "an unchanged main script with imported scripts: each import is fetched and compared; a bad one is ignored" {
    var resources = [_]registry.Resource{
        resource("https://e.com/sw.js", "main"),
        resource("https://e.com/a.js", "a1"),
        resource("https://e.com/b.js", "b1"),
    };
    const newest: registry.FetchPlan.Newest = .{ .script_url = @constCast("https://e.com/sw.js"), .worker_type = .classic, .classic_scripts_imported = true, .resources = &resources };
    const p = plan("https://e.com/sw.js", "https://e.com/", newest);

    // a.js unchanged, b.js now a 404: no update - the bad response does not
    // count (step 21.1.8) - and every import was fetched.
    var unchanged: Table = .{ .entries = &.{
        .{ .url = "https://e.com/sw.js", .body = "main" },
        .{ .url = "https://e.com/a.js", .body = "a1" },
        .{ .url = "https://e.com/b.js", .status = 404, .content_type = "text/html", .body = "gone" },
    } };
    defer unchanged.deinit();
    var a = update_fetch.run(testing.allocator, &p, unchanged.fetcher());
    defer freeOutcome(&a);
    try testing.expect(a.failure == null);
    try testing.expect(!a.has_updated_resources);
    try testing.expectEqual(@as(usize, 3), unchanged.fetched.items.len);

    // a.js changed: updated, and the loop still fetched b.js (it does not
    // break, so the map is complete).
    var changed: Table = .{ .entries = &.{
        .{ .url = "https://e.com/sw.js", .body = "main" },
        .{ .url = "https://e.com/a.js", .body = "a2" },
        .{ .url = "https://e.com/b.js", .body = "b1" },
    } };
    defer changed.deinit();
    var b = update_fetch.run(testing.allocator, &p, changed.fetcher());
    defer freeOutcome(&b);
    try testing.expect(b.has_updated_resources);
    try testing.expectEqual(@as(usize, 3), b.resources.items.len);
    try testing.expectEqual(@as(usize, 3), changed.fetched.items.len);
}

test "a module worker's unchanged main script: the modules its graph imported are fetched and compared too" {
    // The imported module joined the script resource map when the worker's
    // graph was fetched (Registry.addModuleScript); no classic script was
    // imported. Every browser compares it on update (update-bytecheck
    // module cases: Chrome, Firefox and Safari 8/8, wpt.fyi df642c4142).
    var resources = [_]registry.Resource{
        resource("https://e.com/sw.mjs", "main"),
        resource("https://e.com/dep.mjs", "dep1"),
    };
    const newest: registry.FetchPlan.Newest = .{ .script_url = @constCast("https://e.com/sw.mjs"), .worker_type = .module, .classic_scripts_imported = false, .resources = &resources };
    var p = plan("https://e.com/sw.mjs", "https://e.com/", newest);
    p.worker_type = .module;

    var same: Table = .{ .entries = &.{
        .{ .url = "https://e.com/sw.mjs", .body = "main" },
        .{ .url = "https://e.com/dep.mjs", .body = "dep1" },
    } };
    defer same.deinit();
    var a = update_fetch.run(testing.allocator, &p, same.fetcher());
    defer freeOutcome(&a);
    try testing.expect(a.failure == null);
    try testing.expect(!a.has_updated_resources);
    try testing.expectEqual(@as(usize, 2), same.fetched.items.len);

    var changed: Table = .{ .entries = &.{
        .{ .url = "https://e.com/sw.mjs", .body = "main" },
        .{ .url = "https://e.com/dep.mjs", .body = "dep2" },
    } };
    defer changed.deinit();
    var b = update_fetch.run(testing.allocator, &p, changed.fetcher());
    defer freeOutcome(&b);
    try testing.expect(b.has_updated_resources);
}
