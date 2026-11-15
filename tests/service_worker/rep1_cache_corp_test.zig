//! Service Workers 5.4.2 matchAll() step 5.4: a cached "opaque" response
//! that Fetch's cross-origin resource policy check - with the promise's
//! relevant settings object's origin, that settings object, the destination
//! "" and the response's internal response - blocks makes matchAll() (and
//! match(), and CacheStorage's match(), which run it) reject with a
//! TypeError, after the check's COEP CORP violation reports (Fetch steps 4
//! and 6). html/cross-origin-embedder-policy/cache-storage-reporting-*.
//! These cases pin the decision over a cache record, engine-free:
//! `service_worker.cache.api.corpCheckOf`.
const std = @import("std");
const testing = std.testing;
const service_worker = @import("service_worker");
const fetch = @import("fetch");
const api = service_worker.cache.api;
const records = service_worker.cache.records;
const EmbedderPolicy = fetch.internal.EmbedderPolicy;

const page = "https://web-platform.test:8443";
const image = "https://www1.web-platform.test:8443/images/blue.png";

/// A record as put() keeps it: `response_type` (Fetch's ResponseType, 4 =
/// opaque, 5 = opaque-redirect, 1 = basic), its internal response's URL
/// list and headers.
fn record(response_type: u8, url_list: []const []const u8, headers: []const [2][]const u8, includes_credentials: bool) !records.StoredResponse {
    // The fixtures are a few bytes: an allocation failure here fails the
    // test (only the code under test is put under allocation failure).
    const allocator = testing.allocator;
    const list = try allocator.alloc([]u8, url_list.len);
    for (url_list, list) |url, *slot| slot.* = try allocator.dupe(u8, url);
    const out = try allocator.alloc(records.Header, headers.len);
    for (headers, out) |h, *slot| slot.* = .{ .name = try allocator.dupe(u8, h[0]), .value = try allocator.dupe(u8, h[1]) };
    return .{ .response_type = response_type, .url_list = list, .headers = out, .request_includes_credentials = includes_credentials };
}

const require_corp: EmbedderPolicy = .{ .value = .require_corp, .reporting_endpoint = "enforce-endpoint" };
const report_only: EmbedderPolicy = .{ .report_only_value = .require_corp, .report_only_reporting_endpoint = "ro-endpoint" };
const credentialless: EmbedderPolicy = .{ .value = .credentialless };
const none: EmbedderPolicy = .{};

test "an opaque cross-origin record without CORP is blocked under require-corp, with an enforce report" {
    var response = try record(4, &.{image}, &.{}, true);
    defer response.deinit(testing.allocator);
    const check = try api.corpCheckOf(testing.allocator, page, &require_corp, &response);
    try testing.expectEqual(.blocked, check.result);
    try testing.expect(check.enforced_by_embedder_policy);
    try testing.expect(!check.report_only_blocks);
}

test "report-only require-corp allows the record and asks for a reporting report" {
    var response = try record(4, &.{image}, &.{}, true);
    defer response.deinit(testing.allocator);
    const check = try api.corpCheckOf(testing.allocator, page, &report_only, &response);
    try testing.expectEqual(.allowed, check.result);
    try testing.expect(check.report_only_blocks);
    try testing.expect(!check.enforced_by_embedder_policy);
}

test "unsafe-none checks only the header: no CORP header is allowed, CORP same-origin is blocked without a report" {
    var plain = try record(4, &.{image}, &.{}, true);
    defer plain.deinit(testing.allocator);
    const allowed = try api.corpCheckOf(testing.allocator, page, &none, &plain);
    try testing.expectEqual(.allowed, allowed.result);
    try testing.expect(!allowed.report_only_blocks and !allowed.enforced_by_embedder_policy);
    // Fetch step 3: the header alone blocks, and no COEP report is made.
    var same_origin = try record(4, &.{image}, &.{.{ "Cross-Origin-Resource-Policy", "same-origin" }}, true);
    defer same_origin.deinit(testing.allocator);
    const blocked = try api.corpCheckOf(testing.allocator, page, &none, &same_origin);
    try testing.expectEqual(.blocked, blocked.result);
    try testing.expect(!blocked.report_only_blocks and !blocked.enforced_by_embedder_policy);
}

test "CORP cross-origin on the record allows it under require-corp" {
    var response = try record(4, &.{image}, &.{.{ "cross-origin-resource-policy", "cross-origin" }}, true);
    defer response.deinit(testing.allocator);
    const check = try api.corpCheckOf(testing.allocator, page, &require_corp, &response);
    try testing.expectEqual(.allowed, check.result);
    try testing.expect(!check.report_only_blocks and !check.enforced_by_embedder_policy);
}

test "the check reads the response's URL: the last of its URL list, where a redirect ended" {
    // Redirected from a cross-origin URL back to the page's origin: same
    // origin with the response's URL, so require-corp allows it.
    var response = try record(4, &.{ image, page ++ "/images/blue.png" }, &.{}, true);
    defer response.deinit(testing.allocator);
    const check = try api.corpCheckOf(testing.allocator, page, &require_corp, &response);
    try testing.expectEqual(.allowed, check.result);
}

test "credentialless blocks only a record whose request included credentials" {
    var with = try record(4, &.{image}, &.{}, true);
    defer with.deinit(testing.allocator);
    try testing.expectEqual(.blocked, (try api.corpCheckOf(testing.allocator, page, &credentialless, &with)).result);
    var without = try record(4, &.{image}, &.{}, false);
    defer without.deinit(testing.allocator);
    try testing.expectEqual(.allowed, (try api.corpCheckOf(testing.allocator, page, &credentialless, &without)).result);
}

test "only an opaque record is checked: basic and opaque-redirect records are allowed with no report" {
    for ([_]u8{ 1, 5 }) |response_type| {
        var response = try record(response_type, &.{image}, &.{}, true);
        defer response.deinit(testing.allocator);
        const check = try api.corpCheckOf(testing.allocator, page, &require_corp, &response);
        try testing.expectEqual(.allowed, check.result);
        try testing.expect(!check.report_only_blocks and !check.enforced_by_embedder_policy);
    }
}

test "a blocked record's report names its URL list[0], the URL its fetch started at" {
    var response = try record(4, &.{ page ++ "/redirect?to=x", image }, &.{}, true);
    defer response.deinit(testing.allocator);
    const check = try api.corpCheckOf(testing.allocator, page, &require_corp, &response);
    try testing.expectEqual(.blocked, check.result);
    try testing.expectEqualStrings(page ++ "/redirect?to=x", api.reportedUrlOf(&response));
}

test "the check fails only for want of memory, and leaks nothing when it does" {
    // A `same-site` header is not used here: Fetch's schemelessly-same-site
    // step fails closed on any error, out of memory included ("blocked",
    // cross_origin_policies.schemelesslySameSite), so it swallows the
    // failure by design. The require-corp same-origin path reports it.
    var response = try record(4, &.{image}, &.{.{ "Vary", "Accept" }}, true);
    defer response.deinit(testing.allocator);
    try testing.checkAllAllocationFailures(testing.allocator, struct {
        fn run(allocator: std.mem.Allocator, r: *const records.StoredResponse) !void {
            _ = try api.corpCheckOf(allocator, page, &require_corp, r);
        }
    }.run, .{&response});
}
