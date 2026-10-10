//! Implementation for ReportingObserver interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const engine = @import("engine");
const reporting = @import("dom").reporting;
const ReportingObserver = interfaces.ReportingObserver;

pub const State = ReportingObserver.State;

pub const ImplError = error{
    NotImplemented,
};

pub const InternalState = struct {
    allocator: std.mem.Allocator,
    observer: reporting.Observer,
};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator, .observer = .{
        .allocator = allocator,
        .instance = instance,
        .exception_reporter = reportException,
    } };
    instance.getState(State).own._internal = internal;
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    internal.observer.deinit();
    internal.allocator.destroy(internal);
    state.own._internal = null;
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(ctx: runtime.Context, callback: callbacks.ReportingObserverCallback, options: webidl.Opt(dictionaries.ReportingObserverOptions)) !*runtime.Instance {
    // Reporting §4.1 constructor steps 1-3. The binding transfers callback.
    const owned_callback = engine.takeCallbackFunction(@ptrCast(callback));
    const instance = init(ctx.allocator, State, &ReportingObserver.vtable, ctx) catch |err| {
        owned_callback.release();
        return err;
    };
    errdefer runtime.Instance.deinit(instance);
    const observer = try observerOf(instance);
    observer.callback = owned_callback;
    const value: dictionaries.ReportingObserverOptions = if (options.was_passed) options.value else .{};
    observer.buffered = value.buffered orelse false;
    if (value.types) |types| {
        try observer.types.ensureTotalCapacity(ctx.allocator, types.len);
        for (types) |name| observer.types.appendAssumeCapacity(try ctx.allocator.dupe(u8, name.asSlice()));
    }
    return instance;
}

/// Operation: observe
pub fn call_observe(instance: *runtime.Instance) anyerror!void {
    try (try observerOf(instance)).observe();
}

/// Operation: disconnect
pub fn call_disconnect(instance: *runtime.Instance) anyerror!void {
    (try observerOf(instance)).disconnect();
}

/// Operation: takeRecords
pub fn call_takeRecords(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const records = try (try observerOf(instance)).takeRecords(engine.currentRealm() orelse instance.ctx);
    return records.take();
}

fn observerOf(instance: *runtime.Instance) !*reporting.Observer {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    return &internal.observer;
}

fn reportException(host: ?*anyopaque, info: *const engine.ErrorInfo) void {
    const observer_realm: runtime.Context = @ptrCast(@alignCast(host orelse return));
    const global = reporting.globalOf(info.realm orelse observer_realm) orelse return;
    const extracted: runtime.ErrorInfo = .{
        .message = info.message,
        .filename = info.filename,
        .lineno = info.lineno,
        .colno = info.colno,
        .error_value = if (info.error_value == .undefined) null else info.error_value,
    };
    _ = @import("html").report_exception.reportErrorInfo(global, &extracted, .{});
}
