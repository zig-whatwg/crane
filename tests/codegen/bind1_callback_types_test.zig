//! Callback values reach an impl as the engine protocol's borrowed types
//! (lane bind1, 2026-11-23): a callback function type's value as
//! `runtime.BorrowedCallbackFunction`, a callback interface type's as
//! `runtime.BorrowedCallbackInterface` - BORROWED for the call, kept with
//! `keep()` (engine.keepCallbackFunction / keepCallbackInterface). They
//! replace a fake function pointer carrying the binding's Global
//! (`callbacks.X = *const fn (...) R`) and `??*runtime.CallbackWrapper`.
//! Nullability follows the IDL type: `?` only for a nullable one.

const std = @import("std");
const codegen = @import("codegen");
const testing = std.testing;

/// The fixture's generated file `relative`, read whole.
fn generated(relative: []const u8) ![]u8 {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const root = try tmp.dir.realPathFileAlloc(testing.io, ".", testing.allocator);
    defer testing.allocator.free(root);
    var cfg = codegen.config.CodegenConfig{ .allocator = testing.allocator, .dest_root = root };
    defer cfg.deinit();
    try codegen.processSources(testing.allocator, &.{"tests/codegen/fixtures/bind1_callback_types"}, &cfg);
    const path = try std.fs.path.join(testing.allocator, &.{ root, relative });
    defer testing.allocator.free(path);
    return std.Io.Dir.cwd().readFileAlloc(testing.io, path, testing.allocator, .limited(1024 * 1024));
}

fn expectHas(output: []const u8, needle: []const u8) !void {
    if (std.mem.indexOf(u8, output, needle) == null) {
        std.debug.print("expected `{s}` in:\n{s}\n", .{ needle, output });
        return error.TestExpectedEqual;
    }
}

test "a callback function type is the protocol's borrowed callback function" {
    const output = try generated("callbacks/Notify.zig");
    defer testing.allocator.free(output);
    try expectHas(output, "pub const Notify = runtime.BorrowedCallbackFunction;");
    // The IDL signature stays, for the reader.
    try expectHas(output, "callback Notify = undefined (DOMString message, long count)");
    try testing.expect(std.mem.indexOf(u8, output, "*const fn") == null);
}

test "a callback interface argument is the protocol's borrowed callback interface, nullable only when the IDL says" {
    const output = try generated("interfaces/CallbackTypes.zig");
    defer testing.allocator.free(output);
    try expectHas(output, "call_listen(instance: *runtime.Instance, listener: runtime.BorrowedCallbackInterface)");
    try expectHas(output, "call_listenNullable(instance: *runtime.Instance, listener: ?runtime.BorrowedCallbackInterface)");
    try expectHas(output, "call_listenOptional(instance: *runtime.Instance, listener: webidl.Opt(?runtime.BorrowedCallbackInterface))");
    try testing.expect(std.mem.indexOf(u8, output, "CallbackWrapper") == null);
}

test "a dictionary's callback interface member is the protocol's borrowed callback interface" {
    const output = try generated("dictionaries/NotifyInit.zig");
    defer testing.allocator.free(output);
    try expectHas(output, "runtime.BorrowedCallbackInterface");
    try testing.expect(std.mem.indexOf(u8, output, "CallbackWrapper") == null);
}
