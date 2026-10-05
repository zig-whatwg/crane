//! Implementation for PerformanceMark interface
//!
//! Spec: https://w3c.github.io/user-timing/#performancemark

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dictionaries = @import("dictionaries");
const webidl = @import("webidl");
const engine = @import("engine");
const performance_timeline = @import("dom").performance_timeline;
const PerformanceMark = interfaces.PerformanceMark;

pub const State = PerformanceMark.State;

pub const ImplError = error{
    NotImplemented,
};

/// A mark's own state is its detail, which its wrapper keeps
/// (`detail_slot`); its PerformanceEntry attributes are PerformanceEntry's.
pub const InternalState = struct {};

/// The member a mark keeps its detail in (engine.traceValue).
const detail_slot: engine.TracedSlot = .{ .name = "detail" };

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    return runtime.Instance.init(allocator, StateType, vtable, ctx);
}

/// Deinitialize instance: the detail's waiting edge (a mark freed
/// unwrapped), then PerformanceEntry's part.
pub fn deinit(instance: *runtime.Instance) void {
    engine.forgetTracedChild(instance, detail_slot);
    interfaces.PerformanceEntry.deinit(instance);
    // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// Constructor (User Timing 2.2.1)
pub fn call_constructor(ctx: runtime.Context, markName: runtime.DOMString, markOptions: webidl.Opt(dictionaries.PerformanceMarkOptions)) !*runtime.Instance {
    const name = markName.asSlice();
    // 1. On a Window, a PerformanceTiming attribute's name is a SyntaxError.
    if (ctx.isWindow() and performance_timeline.isPerformanceTimingAttribute(name)) return error.SyntaxError;
    const options: dictionaries.PerformanceMarkOptions = if (markOptions.was_passed) markOptions.value else .{};

    // 5. startTime: the option (never negative), else now() of the current
    // global's Performance.
    const start_time: f64 = if (options.startTime) |start| blk: {
        if (start < 0) return error.TypeError;
        break :blk start;
    } else performance_timeline.now(ctx) orelse 0;

    // 7-8. detail: null, or StructuredDeserialize(StructuredSerialize(detail))
    // in the current realm - done before the entry exists, so that a
    // DataCloneError makes none. (StructuredSerializeForStorage: the same
    // but for SharedArrayBuffer, which a non-isolated realm has not got.)
    var detail: ?engine.Owned = null;
    defer if (detail) |d| d.release();
    if (options.detail) |value| {
        if (value != .null) {
            const record = try engine.structuredSerializeForStorage(ctx, value, ctx.allocator);
            defer ctx.allocator.free(record);
            detail = try engine.structuredDeserialize(ctx, record);
        }
    }

    // 2. A new PerformanceMark in the current global object's realm.
    const instance = try init(ctx.allocator, State, &PerformanceMark.vtable, ctx);
    errdefer runtime.Instance.deinit(instance);
    // 3-4, 6. name, entryType "mark", duration 0 (no end time).
    try performance_timeline.initializeEntry(instance, start_time, .mark, name, 0);
    if (detail) |d| engine.traceValue(instance, d.value, detail_slot);
    return instance;
}

/// Getter for detail: the value it was set to, or null.
pub fn get_detail(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const detail = engine.tracedValue(instance, detail_slot) orelse return runtime.JSValue.jsNull;
    return detail.take();
}
