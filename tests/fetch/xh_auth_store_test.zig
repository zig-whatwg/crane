const std = @import("std");
const fetch = @import("fetch");
const Network = fetch.network.NetworkContext;
const a = std.testing.allocator;

test "authentication stores isolate Browsers, partitions, realms and path prefixes" {
    if (!@hasField(Network, "auth_entries")) return error.TestUnexpectedResult;
    var one = Network.init(a);
    defer one.deinit();
    var two = Network.init(a);
    defer two.deinit();
    const store = &one.auth_entries;
    try std.testing.expect((try store.lookup(a, "top", "https://server.test", "/a/")) == null);
    try store.put("top", "https://server.test", "realm", "/a/", "user", "pass");
    try store.put("top", "https://server.test", "deeper", "/a/b/", "deep", "secret");
    var got = (try store.lookup(a, "top", "https://server.test", "/a/b/page")).?;
    defer got.deinit(a);
    try std.testing.expectEqualStrings("deep", got.username);
    try std.testing.expectEqualStrings("secret", got.password);
    try std.testing.expect((try store.lookup(a, "other", "https://server.test", "/a/b/")) == null);
    try std.testing.expect((try store.lookup(a, "top", "https://server.test", "/another/")) == null);
    try std.testing.expect((try store.lookup(a, "top", "http://server.test", "/a/")) == null);
    try std.testing.expect((try two.auth_entries.lookup(a, "top", "https://server.test", "/a/")) == null);
    store.remove("top", "https://server.test", "deeper");
    try std.testing.expectEqualStrings("deep", got.username); // caller owns a copy
    var parent = (try store.lookup(a, "top", "https://server.test", "/a/b/")).?;
    defer parent.deinit(a);
    try std.testing.expectEqualStrings("user", parent.username);
}

test "authentication store bounded eviction and concurrent copied reads" {
    if (!@hasField(Network, "auth_entries")) return error.TestUnexpectedResult;
    var gpa: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
    defer std.testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    var context = Network.init(gpa.allocator());
    defer context.deinit();
    const store = &context.auth_entries;
    store.max_entries = 2;
    try store.put("top", "https://s.test", "1", "/a/", "a", "a");
    try store.put("top", "https://s.test", "2", "/b/", "b", "b");
    try store.put("top", "https://s.test", "3", "/c/", "c", "c");
    try std.testing.expect((try store.lookup(gpa.allocator(), "top", "https://s.test", "/a/")) == null);
    const Hammer = struct {
        fn run(s: @TypeOf(store), allocator: std.mem.Allocator) void {
            for (0..500) |_| {
                s.put("top", "https://s.test", "3", "/c/", "c", "c") catch @panic("put");
                var value = (s.lookup(allocator, "top", "https://s.test", "/c/") catch @panic("read")).?;
                std.debug.assert(std.mem.eql(u8, value.username, "c"));
                value.deinit(allocator);
            }
        }
    };
    const t1 = try std.Thread.spawn(.{}, Hammer.run, .{ store, gpa.allocator() });
    const t2 = std.Thread.spawn(.{}, Hammer.run, .{ store, gpa.allocator() }) catch |err| {
        t1.join();
        return err;
    };
    t1.join();
    t2.join();
}

fn allocationTrial(allocator: std.mem.Allocator) !void {
    if (!@hasField(Network, "auth_entries")) return error.TestUnexpectedResult;
    var context = Network.init(allocator);
    defer context.deinit();
    try context.auth_entries.put("top", "https://s.test", "realm", "/a/file", "user", "pass");
    try context.auth_entries.put("top", "https://s.test", "realm", "/b/file", "new", "secret");
    var credentials = (try context.auth_entries.lookup(allocator, "top", "https://s.test", "/b/deeper")).?;
    defer credentials.deinit(allocator);
    try std.testing.expectEqualStrings("new", credentials.username);
}
test "authentication store owns every partial insertion, replacement and copied lookup" {
    try std.testing.checkAllAllocationFailures(a, allocationTrial, .{});
}
