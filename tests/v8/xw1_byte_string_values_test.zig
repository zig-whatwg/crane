//! ByteString has one byte per JS code unit, unlike UTF-8 USVString.
const std = @import("std");
const v8 = @import("v8");
const ffi = v8.ffi;
const engine = @import("engine");
const testing = std.testing;

fn check() !void {
    try engine.initializeEngine(.{});
    const isolate = ffi.v8_Isolate_New() orelse return error.NoIsolate;
    defer ffi.v8_Isolate_Dispose(isolate);
    ffi.v8_Isolate_Enter(isolate);
    defer ffi.v8_Isolate_Exit(isolate);
    const scope = ffi.v8_HandleScope_New(isolate) orelse return error.NoScope;
    defer ffi.v8_HandleScope_Dispose(scope);
    const context = ffi.v8_Context_New(isolate) orelse return error.NoContext;
    defer ffi.v8_Context_Dispose(context);
    ffi.v8_Context_Enter(context);
    defer ffi.v8_Context_Exit(context);
    var units: [256]u16 = undefined;
    var bytes: [256]u8 = undefined;
    for (&units, &bytes, 0..) |*unit, *byte, i| {
        unit.* = @intCast(i);
        byte.* = @intCast(i);
    }
    const input = ffi.v8_Value_StringFromTwoByte(isolate, &units, units.len) orelse return error.NoString;
    defer ffi.v8_Value_Dispose(input);
    const value = try v8.conversions.fromV8ByteString(testing.allocator, isolate, context, input);
    defer testing.allocator.free(value);
    try testing.expectEqualSlices(u8, &bytes, value);

    const output = try v8.conversions.byteStringToV8([]const u8, isolate, &bytes);
    defer ffi.v8_Value_Dispose(output);
    const round_trip = try v8.conversions.fromV8ByteString(testing.allocator, isolate, context, output);
    defer testing.allocator.free(round_trip);
    try testing.expectEqualSlices(u8, &bytes, round_trip);
    const null_value = try v8.conversions.byteStringToV8(?[]const u8, isolate, null);
    defer ffi.v8_Value_Dispose(null_value);
    try testing.expect(ffi.v8_Value_IsNull(null_value));
}

test "xw1 ByteString input and output preserve every byte, including NUL and nullable results" {
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, struct {
        fn run(out: *anyerror!void) void {
            out.* = check();
        }
    }.run, .{&result});
    thread.join();
    try result;
}

test "xw1 ByteString return metadata defaults to the ordinary string conversion" {
    const Marked = struct {
        pub const byte_string_returns = .{"call_bytes"};
    };
    try testing.expect(v8.interface_mod.returnsByteString(Marked, "call_bytes"));
    try testing.expect(!v8.interface_mod.returnsByteString(Marked, "call_text"));
    try testing.expect(!v8.interface_mod.returnsByteString(struct {}, "call_bytes"));
}

test "xw1 ByteString owns raw bytes through nullable optional and sequence values" {
    try testing.expect(@hasDecl(v8.conversions, "encodeByteStringOwned"));
    if (comptime !@hasDecl(v8.conversions, "encodeByteStringOwned")) return;
    const Opt = @import("webidl").Opt(?[]const u8);
    var value = Opt.passed(try testing.allocator.dupe(u8, "\xc2\x80\xc3\xbf"));
    defer v8.interface_mod.freeConvertedArg(Opt, testing.allocator, value);
    try v8.conversions.encodeByteStringOwned(Opt, testing.allocator, &value);
    try testing.expectEqualSlices(u8, &.{ 0x80, 0xff }, value.value.?);
    var seq = try testing.allocator.alloc([]const u8, 2);
    defer v8.interface_mod.freeConvertedArg([][]const u8, testing.allocator, seq);
    seq[0] = try testing.allocator.dupe(u8, "\xc2\x80");
    seq[1] = try testing.allocator.dupe(u8, "\xc3\xbf");
    try v8.conversions.encodeByteStringOwned([][]const u8, testing.allocator, &seq);
    try testing.expectEqualSlices(u8, &.{0x80}, seq[0]);
    try testing.expectEqualSlices(u8, &.{0xff}, seq[1]);
}

fn encodeWithFailures(a: std.mem.Allocator) !void {
    if (comptime !@hasDecl(v8.conversions, "encodeByteStringOwned")) return;
    var value: []const u8 = try a.dupe(u8, "\xc2\x80\xc3\xbf");
    defer a.free(value);
    try v8.conversions.encodeByteStringOwned([]const u8, a, &value);
    try testing.expectEqualSlices(u8, &.{ 0x80, 0xff }, value);
}

test "xw1 ByteString conversion keeps cleanup valid on allocation failure and validates a whole sequence first" {
    try testing.expect(@hasDecl(v8.conversions, "encodeByteStringOwned"));
    if (comptime !@hasDecl(v8.conversions, "encodeByteStringOwned")) return;
    try testing.checkAllAllocationFailures(testing.allocator, encodeWithFailures, .{});
    var sequence = try testing.allocator.alloc([]const u8, 2);
    defer v8.interface_mod.freeConvertedArg([][]const u8, testing.allocator, sequence);
    sequence[0] = try testing.allocator.dupe(u8, "\xc2\x80");
    sequence[1] = try testing.allocator.dupe(u8, "\xe2\x82\xac");
    try testing.expectError(error.TypeError, v8.conversions.encodeByteStringOwned([][]const u8, testing.allocator, &sequence));
    try testing.expectEqualStrings("\xc2\x80", sequence[0]);
    try testing.expectEqualStrings("\xe2\x82\xac", sequence[1]);
}

fn checkDictionary() !void {
    try engine.initializeEngine(.{});
    const isolate = ffi.v8_Isolate_New() orelse return error.NoIsolate;
    defer ffi.v8_Isolate_Dispose(isolate);
    ffi.v8_Isolate_Enter(isolate);
    defer ffi.v8_Isolate_Exit(isolate);
    const scope = ffi.v8_HandleScope_New(isolate) orelse return error.NoScope;
    defer ffi.v8_HandleScope_Dispose(scope);
    const context = ffi.v8_Context_New(isolate) orelse return error.NoContext;
    defer ffi.v8_Context_Dispose(context);
    ffi.v8_Context_Enter(context);
    defer ffi.v8_Context_Exit(context);
    const source = "({ bytes: '\\u0080\\u00ff', text: '\\u0080\\u00ff' })";
    const text = ffi.v8_String_NewFromUtf8(isolate, source.ptr, source.len) orelse return error.NoString;
    defer ffi.v8_String_Dispose(text);
    const script = ffi.v8_Script_Compile(context, text) orelse return error.NoScript;
    defer ffi.v8_Script_Dispose(script);
    const object = ffi.v8_Script_Run(context, script) orelse return error.NoObject;
    defer ffi.v8_Value_Dispose(object);
    const Dict = struct {
        bytes: ?[]const u8 = null,
        text: ?[]const u8 = null,
        pub const byte_string_members = .{"bytes"};
    };
    const value = try v8.conversions.fromV8Value(Dict, testing.allocator, isolate, context, object);
    defer v8.interface_mod.freeConvertedArg(Dict, testing.allocator, value);
    try testing.expectEqualSlices(u8, &.{ 0x80, 0xff }, value.bytes.?);
    try testing.expectEqualStrings("\xc2\x80\xc3\xbf", value.text.?);
}

test "xw1 dictionary ByteString is raw while its USVString neighbour stays UTF-8" {
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, struct {
        fn run(out: *anyerror!void) void {
            out.* = checkDictionary();
        }
    }.run, .{&result});
    thread.join();
    try result;
}
