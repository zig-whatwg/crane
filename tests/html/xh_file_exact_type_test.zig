//! Construction-only type restoration for HTML's "create an entry".
//! Shared storage is obtained through a real blob URL, never impl internals.
const std = @import("std");
const Browser = @import("browser").Browser;
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const blob_bytes = @import("dom").blob_bytes;

const Case = enum { fresh, shared, oom, clone };
const old_type = "text/plain;charset=gbk";
const exact_type = "text/plain;charset=GBK";

fn exercise(comptime case: Case) !void {
    if (!@hasDecl(blob_bytes, "setExactType")) return error.TestUnexpectedResult;
    if (case == .clone) {
        interfaces.process_hooks.startHooksForTest();
        runtime.initializeRuntime(std.testing.allocator);
        defer runtime.deinitializeRuntime();
        var context = try runtime.ContextData.init(std.testing.allocator, .{});
        defer context.deinit();
        const blob = try blob_bytes.createWithType(&context, "body", exact_type);
        // No engine realm: releaseIfUnwrapped deliberately leaves native
        // objects to their caller (Instance's contract).
        defer runtime.Instance.deinit(blob);
        var serialized = runtime.SerializationRecord.init(std.testing.allocator, false);
        defer serialized.deinit();
        try interfaces.Blob.serializationSteps(blob, &serialized);
        var reader: runtime.DeserializationRecord = .{ .bytes = serialized.bytes.items };
        const copy = try interfaces.Blob.serializable_steps.?.deserialize(&reader, &context);
        defer runtime.Instance.deinit(copy);
        var content_type = try interfaces.Blob.get_type(copy);
        defer content_type.deinit(std.testing.allocator);
        try std.testing.expectEqualStrings(exact_type, content_type.asSlice());
        try std.testing.expectEqualStrings("body", blob_bytes.bytesOf(copy).?);
        try std.testing.expectEqual(serialized.bytes.items.len, reader.position);
        return;
    }
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    const browser = try Browser.init(failing.allocator(), .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const realm = browser.getRealm() orelse return error.NoRealm;

    if (case == .shared) {
        const held = try browser.evaluateScript(
            "globalThis.file = new File(['body'], 'name', {type: 'text/plain;charset=gbk'});" ++
                "globalThis.url = URL.createObjectURL(file); file",
        );
        defer held.release();
        const file = engine.convertToPlatformObject(realm, held.borrow()) orelse return error.NotAFile;
        try std.testing.expectError(error.InvalidState, blob_bytes.setExactType(file, exact_type));
        var content_type = try interfaces.Blob.get_type(file);
        defer content_type.deinit(realm.allocator);
        try std.testing.expectEqualStrings(old_type, content_type.asSlice());
        try std.testing.expectEqualStrings("body", blob_bytes.bytesOf(file).?);
        return;
    }

    const parts = try browser.evaluateScript("['body']");
    defer parts.release();
    // File is fresh and unwrapped: the production hook runs at this point,
    // before FormData traces or exposes it.
    const file = try interfaces.File.call_constructor(realm, parts.borrow(), "name", .passed(.{
        .base = .{ .type = runtime.DOMString.initInterned(old_type) },
        .lastModified = 123,
    }));
    const generation = runtime.SlabAllocator.generationOf(file);
    defer file.releaseIfUnwrapped(generation);
    const bytes = blob_bytes.bytesOf(file).?;
    if (case == .oom) {
        failing.fail_index = failing.alloc_index;
        const result = blob_bytes.setExactType(file, exact_type);
        failing.fail_index = std.math.maxInt(usize);
        try std.testing.expectError(error.OutOfMemory, result);
        try std.testing.expect(failing.has_induced_failure);
    } else {
        try blob_bytes.setExactType(file, exact_type);
    }
    var content_type = try interfaces.Blob.get_type(file);
    defer content_type.deinit(realm.allocator);
    try std.testing.expectEqualStrings(if (case == .oom) old_type else exact_type, content_type.asSlice());
    try std.testing.expectEqualStrings("body", blob_bytes.bytesOf(file).?);
    try std.testing.expectEqual(bytes.ptr, blob_bytes.bytesOf(file).?.ptr);
    try std.testing.expectEqual(@as(i64, 123), try interfaces.File.get_lastModified(file));
}

fn onThread(comptime case: Case) !void {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            exercise(case) catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

test "a fresh File preserves an exact type without changing its bytes or date" {
    try onThread(.fresh);
}
test "exact type restoration refuses storage held by a blob URL" {
    try onThread(.shared);
}
test "allocation failure preserves a fresh File's original type and bytes" {
    try onThread(.oom);
}
test "Blob serialization steps round-trip an exact MIME type and bytes" {
    try onThread(.clone);
}
