//! HTML lastModified reads a source time or the current local time.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const platform = @import("platform");

test "dp1 Document accepts the source modification time as a construction fact" {
    try std.testing.expect(interfaces.Document.takesConstructionArg("last_modified"));
    try std.testing.expect(interfaces.XMLDocument.takesConstructionArg("last_modified"));
    if (comptime interfaces.Document.takesConstructionArg("last_modified") and @hasDecl(platform, "localDateTime")) {
        const allocator = std.testing.allocator;
        interfaces.process_hooks.startHooksForTest();
        runtime.initializeRuntime(allocator);
        defer runtime.deinitializeRuntime();
        var context = try runtime.ContextData.init(allocator, .{});
        defer context.deinit();
        // Zero is a known source time, never an unknown sentinel. Preserve
        // pre-epoch nanoseconds as well as a positive source timestamp.
        for ([_]i64{ -1, 0, 1672531200123456789 }) |ns_since_epoch| {
            const timestamp: platform.WallTime = .{ .ns_since_epoch = ns_since_epoch };
            inline for (.{ interfaces.Document, interfaces.XMLDocument }) |Interface| {
                const document = try Interface.initWith(allocator, &context, .{ .last_modified = timestamp });
                defer Interface.deinit(document);
                var actual = try interfaces.Document.get_lastModified(document);
                defer actual.deinit(allocator);
                var buffer: [32]u8 = undefined;
                const expected = try formatted(&buffer, platform.localDateTime(timestamp));
                try std.testing.expectEqualStrings(expected, actual.asSlice());
            }
        }
    }
}

test "dp1 unknown lastModified is current local time" {
    const allocator = std.testing.allocator;
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(allocator, .{});
    defer context.deinit();
    inline for (.{ false, true }) |explicit_null| {
        const document = if (explicit_null)
            try interfaces.Document.initWith(allocator, &context, .{ .last_modified = @as(?platform.WallTime, null) })
        else
            try interfaces.Document.call_constructor(&context);
        defer interfaces.Document.deinit(document);
        const before = platform.wallSeconds();
        var actual = try interfaces.Document.get_lastModified(document);
        defer actual.deinit(allocator);
        const after = platform.wallSeconds();
        try std.testing.expect(!std.mem.eql(u8, "01/01/1970 00:00:00", actual.asSlice()));
        if (comptime @hasDecl(platform, "localDateTime")) {
            var first: [32]u8 = undefined;
            var last: [32]u8 = undefined;
            const first_string = try formatted(&first, platform.localDateTime(.{ .ns_since_epoch = before * std.time.ns_per_s }));
            const last_string = try formatted(&last, platform.localDateTime(.{ .ns_since_epoch = after * std.time.ns_per_s }));
            try std.testing.expect(std.mem.eql(u8, actual.asSlice(), first_string) or std.mem.eql(u8, actual.asSlice(), last_string));
        }
    }
}

test "dp1 lastModified returns strings with the context allocator" {
    const allocator = std.testing.allocator;
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(allocator, .{});
    defer context.deinit();
    var construction = std.testing.FailingAllocator.init(allocator, .{});
    const document = try interfaces.Document.initWith(construction.allocator(), &context, .{});
    defer interfaces.Document.deinit(document);

    // The document's own allocator may differ from the allocator with
    // which bindings free returned DOMStrings (instance.ctx.allocator).
    construction.fail_index = construction.alloc_index;
    var value = try interfaces.Document.get_lastModified(document);
    defer value.deinit(allocator);
    try std.testing.expect(value.asSlice().len >= 19);
    try std.testing.expect(!construction.has_induced_failure);
}

fn formatted(buffer: []u8, time: anytype) ![]const u8 {
    return std.fmt.bufPrint(buffer, "{d:0>2}/{d:0>2}/{d:0>4} {d:0>2}:{d:0>2}:{d:0>2}", .{
        time.month, time.day, @as(u32, @intCast(time.year)), time.hour, time.minute, time.second,
    });
}
