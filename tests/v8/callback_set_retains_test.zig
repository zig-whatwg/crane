//! An agent's set of live callback wrappers (callback_registry.Live, on its
//! record) is the agent's: its storage comes from the agent's allocator
//! (AgentOptions.allocator), and it keeps its capacity when it empties.
//!
//! Every addEventListener and removeEventListener converts its callback
//! argument into a CallbackWrapper, which joins the set and leaves it when
//! the conversion is freed. The set was on std.heap.page_allocator and freed
//! its storage whenever it emptied, so an add/remove loop - 0, 1, 0 wrappers
//! - mapped a fresh page and unmapped it on every call: 80% of
//! events.add-remove-listener in lane perf2's profile (batch 2,
//! tmp/plans/perf2b2-design.md). WTF's HashTable, Blink's and WebKit's, never
//! frees a table its last entry leaves: it shrinks only while it is larger
//! than its minimum size (WebKit Source/WTF/wtf/HashTable.h `shouldShrink`,
//! `tableSize > KeyTraits::minimumTableSize`; Blink platform/wtf/hash_table.h
//! `ShouldShrink`, `table_size_ > KeyTraits::kMinimumTableSize`; both 8).
//!
//! The test counts the allocations the agent's allocator makes over many
//! make-and-free cycles of a wrapper: one for the set's first storage, none
//! after - no churn, measured without timing.

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const protocol = @import("engine");
const interfaces = @import("interfaces");

const no_hooks: protocol.HostHooks = .{};

const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, global_this: runtime.JSValue, host: ?*anyopaque) ?*runtime.Instance {
        _ = global_this;
        _ = host;
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
    }
};

/// c_allocator, counting the allocations made through it. Atomic: an
/// agent's allocator may be reached off its thread.
const Counting = struct {
    allocations: std.atomic.Value(usize) = .init(0),

    fn allocator(self: *Counting) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }

    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ret_addr: usize) ?[*]u8 {
        const self: *Counting = @ptrCast(@alignCast(ctx));
        _ = self.allocations.fetchAdd(1, .monotonic);
        return std.heap.c_allocator.rawAlloc(len, alignment, ret_addr);
    }

    fn resize(_: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) bool {
        return std.heap.c_allocator.rawResize(memory, alignment, new_len, ret_addr);
    }

    fn remap(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
        const self: *Counting = @ptrCast(@alignCast(ctx));
        _ = self.allocations.fetchAdd(1, .monotonic);
        return std.heap.c_allocator.rawRemap(memory, alignment, new_len, ret_addr);
    }

    fn free(_: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ret_addr: usize) void {
        std.heap.c_allocator.rawFree(memory, alignment, ret_addr);
    }
};

const CallbackWrapper = v8.callback_wrapper_mod.CallbackWrapper;

/// A callback wrapper for a function made in `realm` of `agent`, as the
/// binding makes one for a callback argument.
fn wrapperIn(isolate: *ffi.Isolate, realm: runtime.Context) !*CallbackWrapper {
    const scope = ffi.v8_HandleScope_New(isolate) orelse return error.HandleScopeFailed;
    defer ffi.v8_HandleScope_Dispose(scope);
    const context: *ffi.Context = @ptrCast(@alignCast(realm.engine_ctx orelse return error.NoContext));
    ffi.v8_Context_Enter(context);
    defer ffi.v8_Context_Exit(context);
    const code = "(() => 1)";
    const text = ffi.v8_String_NewFromUtf8(isolate, code.ptr, code.len) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(text);
    const script = ffi.v8_Script_Compile(context, text) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    // The wrapper takes this handle over.
    const function = ffi.v8_Script_Run(context, script) orelse return error.RunFailed;
    errdefer ffi.v8_Value_Dispose(function);
    return CallbackWrapper.initFunction(testing.allocator, isolate, context, @ptrCast(function));
}

fn setEmptiesWithoutChurn() !void {
    var counting: Counting = .{};
    const agent = try protocol.createAgent(.{ .can_block = true, .from_snapshot = false, .hooks = &no_hooks, .host = null, .allocator = counting.allocator() });
    defer protocol.destroyAgent(agent);
    const realm = try protocol.createWindowRealm(&.{
        .agent = agent,
        .allocator = std.heap.c_allocator,
        .from_snapshot = false,
        .timer = null,
        .origin = "https://example.test",
        .create_global_object = WindowHost.createGlobalObject,
    });
    defer protocol.destroyWindowRealm(realm, .global_detached);
    const isolate: *ffi.Isolate = @ptrCast(@alignCast(agent));
    ffi.v8_Isolate_Enter(isolate);
    defer ffi.v8_Isolate_Exit(isolate);
    const live = v8.protocol_agents.callbacksOf(isolate) orelse return error.NoCallbackSet;
    try testing.expectEqual(@as(usize, 0), live.count());

    // The first wrapper: the set's storage, from the agent's allocator.
    const before_first = counting.allocations.load(.monotonic);
    (try wrapperIn(isolate, realm)).deinit();
    try testing.expectEqual(@as(usize, 0), live.count());
    try testing.expect(counting.allocations.load(.monotonic) > before_first);
    // Emptied, it keeps its storage.
    try testing.expect(live.capacity() > 0);

    // Then a make-and-free loop - an add/remove loop's conversions - makes
    // no allocation of the agent's at all.
    const before_loop = counting.allocations.load(.monotonic);
    for (0..500) |_| (try wrapperIn(isolate, realm)).deinit();
    try testing.expectEqual(@as(usize, 0), live.count());
    try testing.expectEqual(before_loop, counting.allocations.load(.monotonic));
}

test "an agent's callback set comes from the agent's allocator and keeps its storage when it empties" {
    test_process.start();
    var failure: ?anyerror = null;
    const Run = struct {
        fn main(out: *?anyerror) void {
            setEmptiesWithoutChurn() catch |err| {
                out.* = err;
            };
        }
    };
    const thread = try std.Thread.spawn(.{ .stack_size = 16 * 1024 * 1024 }, Run.main, .{&failure});
    thread.join();
    if (failure) |err| return err;
}
