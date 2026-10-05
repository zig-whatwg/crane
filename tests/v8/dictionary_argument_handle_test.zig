//! A dictionary argument's own handle goes when the call returns, when the
//! dictionary has a sequence member.
//!
//! The binding releases an argument's Global right after converting it when
//! no part of the converted value can alias it (`argHandleIsCopied`). A
//! dictionary reads each member through its own Get, so no member aliases the
//! dictionary's handle - but the rule held every member type to an allowlist
//! that had no case for a sequence, so StructuredSerializeOptions
//! ({ sequence<object> transfer }) kept the handle: one 16-byte Global per
//! MessagePort / Worker / DedicatedWorkerGlobalScope postMessage(message,
//! options) call (workers2's leaks --atExit over 300 worker files). A
//! sequence reads its elements through their own handles too (v8_Array_Get),
//! so a sequence member is as safe as its elements.
//!
//! The handle tests read V8's own live count against a control that takes
//! the same binding path with nothing to keep
//! (docs/lessons/testing-a-counter-that-drifts-per-call-hides-a-leak-per-call.md).

const std = @import("std");
const runtime = @import("runtime");
const v8 = @import("v8");
const engine = @import("engine");
const interfaces = @import("interfaces");
const webidl = @import("webidl");
const ffi = v8.ffi;

const copied = v8.interface_mod.argHandleIsCopied;

/// StructuredSerializeOptions' shape (dictionaries.StructuredSerializeOptions).
const OptionsShaped = struct { transfer: ?[]const runtime.JSValue = null };

test "a dictionary whose member is a sequence of member-safe elements is copied" {
    try std.testing.expect(copied(OptionsShaped));
    try std.testing.expect(copied(webidl.Opt(OptionsShaped)));
    try std.testing.expect(copied(struct { names: ?[]const runtime.DOMString = null, objects: []const runtime.JSValue = &.{} }));
}

test "a dictionary with a sequence of itself is walked once: the rest of its members decide" {
    // AuctionAdConfig.componentAuctions, HIDCollectionInfo.children. Once a
    // sequence<any> member let the walk go on past the members before it, the
    // self-reference recursed forever (the bindings stopped compiling).
    const Tree = struct {
        name: ?runtime.DOMString = null,
        data: ?[]const runtime.JSValue = null,
        children: ?[]const @This() = null,
    };
    try std.testing.expect(copied(Tree));
    const UnsafeTree = struct {
        children: ?[]const @This() = null,
        raw: ?*anyopaque = null,
    };
    try std.testing.expect(!copied(UnsafeTree));
}

test "a sequence of unknown pointers still keeps the dictionary's handle" {
    // The default stays the safe one: an element type nothing names.
    try std.testing.expect(!copied(struct { items: ?[]const *anyopaque = null }));
    try std.testing.expect(!copied(struct { nested: ?[]const []const *anyopaque = null }));
    // A top-level sequence<any> argument is unchanged: its elements are kept.
    try std.testing.expect(!copied([]const runtime.JSValue));
}

var isolate_once: ?*ffi.Isolate = null;
var context_once: ?*ffi.Context = null;
var realm_once: ?runtime.Context = null;

/// One isolate and realm for the file, registered with the context manager
/// as a page's is, every interface installed and the probe on the global.
fn realm() !runtime.Context {
    if (realm_once) |r| return r;
    try engine.initializeEngine(.{});
    interfaces.process_hooks.startHooksForTest();
    const i = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
    ffi.v8_Isolate_Enter(i);
    _ = ffi.v8_HandleScope_New(i);
    const context = ffi.v8_Context_New(i) orelse return error.ContextCreationFailed;
    ffi.v8_Context_Enter(context);
    v8.context_manager.init(std.heap.page_allocator) catch {};
    const r = try v8.context_manager.getOrCreate(context, std.heap.page_allocator);
    runtime.SlabAllocator.init(std.heap.page_allocator);
    runtime.ArenaAllocator.init(std.heap.page_allocator);
    v8.interface_bindings.registerAllInterfaces(i, context);
    v8.V8Interface(Probe).registerGlobal(i, context, Probe.Meta.name);
    isolate_once = i;
    context_once = context;
    realm_once = r;
    return r;
}

fn eval(code: []const u8) !*ffi.Value {
    const context = context_once.?;
    const text = ffi.v8_String_NewFromUtf8(isolate_once.?, code.ptr, @intCast(code.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(text);
    const script = ffi.v8_Script_Compile(context, text) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    return ffi.v8_Script_Run(context, script) orelse error.RunFailed;
}

fn evalInt(code: []const u8) !i32 {
    const value = try eval(code);
    defer ffi.v8_Value_Dispose(value);
    return ffi.v8_Value_Int32Value(value, context_once.?);
}

/// V8's global handle bytes left by 64 runs of `body`, after a collection.
fn handleBytesLeftBy(comptime body: []const u8) !i64 {
    const isolate = isolate_once.?;
    _ = try evalInt("(() => { for (let i = 0; i < 2; i++) { " ++ body ++ " } return 0 })()");
    ffi.v8_Isolate_RequestGarbageCollection(isolate);
    const before: i64 = @intCast(ffi.v8_Isolate_GetGlobalHandleBytes(isolate));
    _ = try evalInt("(() => { for (let i = 0; i < 64; i++) { " ++ body ++ " } return 0 })()");
    ffi.v8_Isolate_RequestGarbageCollection(isolate);
    return @as(i64, @intCast(ffi.v8_Isolate_GetGlobalHandleBytes(isolate))) - before;
}

fn oneHandleBytes() i64 {
    const isolate = isolate_once.?;
    const start = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    const one = ffi.v8_Number_New(isolate, 1);
    const with_one = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    ffi.v8_Value_Dispose(@ptrCast(one));
    return @intCast(with_one - start);
}

/// A static operation taking `(any, optional StructuredSerializeOptions)` -
/// the conversion path of postMessage's second overload.
const Probe = struct {
    pub const Meta = struct {
        pub const name = "BceDictionaryProbe";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        pub const exposed_in_all_contexts = true;
        pub const properties = .{};
        pub const methods = .{};
        pub const static_methods = .{.{ "take", "call_static_take", 1 }};
        pub const own_methods = .{"take"};
        pub const inherited_methods = .{};
        pub const eager_properties = .{};
        pub const lazy_properties = .{};
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(Meta.BaseType, Meta.MixinTypes, struct {});

    pub fn call_static_take(instance: *runtime.Instance, message: runtime.JSValue, options: webidl.Opt(OptionsShaped)) anyerror!void {
        _ = instance;
        _ = message;
        _ = options;
    }
};

test "a dictionary argument with a sequence member leaves no handle per call" {
    _ = try realm();
    const control = try handleBytesLeftBy("BceDictionaryProbe.take('x');");
    const with_options = try handleBytesLeftBy("BceDictionaryProbe.take('x', {});");
    const one = oneHandleBytes();
    if (with_options - control >= one * 8) {
        std.debug.print("64 calls with an options dictionary left {d} bytes of global handles; the control left {d} ({d} a handle)\n", .{ with_options, control, one });
        return error.HandlesLeaked;
    }
}

test "MessagePort.postMessage(message, options) - its second overload, reached through overload resolution - leaves no handle per call" {
    _ = try realm();
    _ = try evalInt("globalThis.channel = new MessageChannel(); 0");
    const control = try handleBytesLeftBy("channel.port1.postMessage('x', []);");
    const with_options = try handleBytesLeftBy("channel.port1.postMessage('x', {});");
    const one = oneHandleBytes();
    if (with_options - control >= one * 8) {
        std.debug.print("64 postMessage(message, options) calls left {d} bytes of global handles; postMessage(message, []) left {d} ({d} a handle)\n", .{ with_options, control, one });
        return error.HandlesLeaked;
    }
}
