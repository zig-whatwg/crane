//! A Browser's HTTP cache (lane httpcache1): every Browser has its own,
//! sized by BrowserConfig.http_cache, on its network context - and
//! Clear-Site-Data's "cache" type empties the origin's responses in it, in
//! every partition, the exact origin only (Chrome and Safari; the spec's
//! host rule is theirs to differ from - src/browser/clear_site_data.zig).
//! Each Browser allocates from a DebugAllocator of its own (AGENTS.md: a
//! shared std.testing.allocator makes two Browsers take turns).
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const fetch = @import("fetch");

fn networkOf(browser: *browser_mod.Browser) !*fetch.network.NetworkContext {
    return browser.scope.of(fetch.network.NetworkContext);
}

fn store(cache: *fetch.cache.HttpCache, partition: []const u8, url: []const u8) !void {
    cache.publish(try fetch.cache.StoredResponse.create(cache.allocator, .{
        .partition = partition,
        .url = url,
        .status = 200,
        .headers = &.{.{ .name = "Cache-Control", .value = "max-age=60" }},
        .body = "x",
        .request_time = 1,
        .response_time = 1,
    }));
}

test "hc1 Browser: each Browser has an HTTP cache of its own, sized by its config" {
    var debug_a: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
    defer testing.expect(debug_a.deinit() == .ok) catch @panic("Browser A leaked");
    var debug_b: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
    defer testing.expect(debug_b.deinit() == .ok) catch @panic("Browser B leaked");
    const a = try browser_mod.Browser.init(debug_a.allocator(), .{ .persist_storage = false, .snapshot_path = "" });
    defer a.deinit();
    const b = try browser_mod.Browser.init(debug_b.allocator(), .{
        .persist_storage = false,
        .snapshot_path = "",
        .http_cache = .{ .max_bytes = 1024 * 1024, .max_entry_bytes = 4096 },
    });
    defer b.deinit();
    const cache_a = (try networkOf(a)).http_cache.?;
    const cache_b = (try networkOf(b)).http_cache.?;
    try testing.expect(cache_a != cache_b);
    try testing.expectEqual(@as(usize, 50 * 1024 * 1024), cache_a.config.max_bytes);
    try testing.expectEqual(@as(usize, 4096), cache_b.maxEntryBytes());
    try store(cache_a, "https://top.test", "https://a.test/x");
    try testing.expect(cache_b.lookup("https://top.test", "https://a.test/x") == null);
    // A Browser with a cap of 0 has none.
    var debug_c: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
    defer testing.expect(debug_c.deinit() == .ok) catch @panic("Browser C leaked");
    const c = try browser_mod.Browser.init(debug_c.allocator(), .{ .persist_storage = false, .snapshot_path = "", .http_cache = .{ .max_bytes = 0 } });
    defer c.deinit();
    try testing.expect((try networkOf(c)).http_cache == null);
}

test "hc1 Browser: Clear-Site-Data cache removes the exact origin's responses, in every partition" {
    var debug: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
    defer testing.expect(debug.deinit() == .ok) catch @panic("leaked");
    const browser = try browser_mod.Browser.init(debug.allocator(), .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    const network = try networkOf(browser);
    const cache = network.http_cache.?;
    try store(cache, "https://top.test", "https://a.test/x");
    try store(cache, "https://other.test", "https://a.test/y");
    try store(cache, "https://top.test", "http://a.test/x"); // another scheme
    try store(cache, "https://top.test", "https://a.test:8443/x"); // another port
    try store(cache, "https://top.test", "https://sub.a.test/x");
    // What HTTP-network fetch calls for a `Clear-Site-Data: "cache"` response
    // of https://a.test (fetch.algorithms.clear_site_data).
    const clearer = network.site_data.?;
    clearer.clear(clearer.context, "https://a.test", .{ .cache = true });
    try testing.expect(cache.lookup("https://top.test", "https://a.test/x") == null);
    try testing.expect(cache.lookup("https://other.test", "https://a.test/y") == null);
    cache.lookup("https://top.test", "http://a.test/x").?.release();
    cache.lookup("https://top.test", "https://a.test:8443/x").?.release();
    cache.lookup("https://top.test", "https://sub.a.test/x").?.release();
    // Another type leaves the cache alone.
    clearer.clear(clearer.context, "http://a.test", .{ .storage = true });
    cache.lookup("https://top.test", "http://a.test/x").?.release();
}
