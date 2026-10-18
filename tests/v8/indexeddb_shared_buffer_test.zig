//! IndexedDB 7.4 copies shared buffer keys; storage serialization rejects SAB.
//! Safari supports SAB keys, Firefox rejects them, and Chrome's aligned WPT
//! run crashes (2026-10-18). With no browser majority, the existing spec wins.
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const keys = @import("dom").indexeddb_keys;
const Page = @import("urlpattern_realm.zig").Page;
const testing = std.testing;

test "IndexedDB shared buffer keys copy the buffer and the view range" {
    const page = try Page.open();
    defer page.close();
    try page.run("globalThis.iw1Buffer = new SharedArrayBuffer(4)");

    const cases = .{
        .{ "iw1Buffer", &[_]u8{ 1, 2, 3, 4 }, false },
        .{ "new Uint8Array(iw1Buffer, 1, 2)", &[_]u8{ 2, 3 }, false },
        .{ "new DataView(iw1Buffer, 2, 1)", &[_]u8{3}, false },
        .{ "[iw1Buffer]", &[_]u8{ 1, 2, 3, 4 }, true },
    };
    inline for (cases) |case| {
        try page.run("new Uint8Array(iw1Buffer).set([1, 2, 3, 4])");
        const input = try evaluate(page.realm, case[0]);
        defer input.release();
        var key = try keys.require(page.realm, input.value, testing.allocator);
        defer key.deinit();
        if (case[2]) try testing.expectEqual(.array, key.key_type);
        const binary = if (case[2]) &key.value.array[0] else &key;
        try testing.expectEqual(.binary, binary.key_type);
        try testing.expectEqualSlices(u8, case[1], binary.value.binary);
        try page.run("new Uint8Array(iw1Buffer).fill(9)");
        try testing.expectEqualSlices(u8, case[1], binary.value.binary);
    }
}

test "IndexedDB storage serialization rejects shared buffers at any depth" {
    const page = try Page.open();
    defer page.close();
    for ([_][]const u8{
        "new SharedArrayBuffer(4)",
        "new Uint8Array(new SharedArrayBuffer(4))",
        "({ nested: [{ buffer: new SharedArrayBuffer(4) }] })",
    }) |source| {
        const input = try evaluate(page.realm, source);
        defer input.release();
        const Serialization = struct {
            realm: runtime.Context,
            value: runtime.JSValue,
            fn run(data: ?*anyopaque) engine.Error!void {
                const self: *@This() = @ptrCast(@alignCast(data.?));
                const bytes = try engine.structuredSerializeForStorage(self.realm, self.value, testing.allocator);
                testing.allocator.free(bytes);
            }
        };
        var serialization: Serialization = .{ .realm = page.realm, .value = input.value };
        // The protocol can return DataCloneError before throwing, or leave
        // an actual exception pending. Observe the completed JS exception.
        const thrown = (try engine.completionOf(page.realm, Serialization.run, &serialization)) orelse return error.TestExpectedError;
        defer thrown.release();
        const name = try engine.getProperty(page.realm, thrown.value, "name");
        defer name.release();
        const text = try engine.convertToDOMString(page.realm, name.value, testing.allocator);
        defer testing.allocator.free(text);
        try testing.expectEqualStrings("DataCloneError", text);
    }
}

fn evaluate(realm: runtime.Context, source: []const u8) !engine.Owned {
    const Reports = struct {
        count: usize = 0,
        fn report(host: ?*anyopaque, _: *const engine.ErrorInfo) void {
            const self: *@This() = @ptrCast(@alignCast(host.?));
            self.count += 1;
        }
    };
    var reports: Reports = .{};
    const result = try engine.evaluateClassicScript(realm, .{ .utf8 = source }, "", null, .{ .host = &reports, .report = Reports.report });
    errdefer result.release();
    try testing.expectEqual(@as(usize, 0), reports.count);
    return result;
}
