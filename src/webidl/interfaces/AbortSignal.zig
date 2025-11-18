//! Generated from: dom.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const AbortSignalImpl = @import("impls").AbortSignal;
const EventTarget = @import("interfaces").EventTarget;
const EventHandler = @import("typedefs").EventHandler;

pub const AbortSignal = struct {
    pub const Meta = struct {
        pub const name = "AbortSignal";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;
    };

    pub const State = runtime.FlattenedState(
        struct {
            aborted: bool = undefined,
            reason: anyopaque = undefined,
            onabort: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(AbortSignal, .{
        .deinit_fn = &deinit_wrapper,

        .get_aborted = &get_aborted,
        .get_onabort = &get_onabort,
        .get_reason = &get_reason,

        .set_onabort = &set_onabort,

        .call__any = &call__any,
        .call_abort = &call_abort,
        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_removeEventListener = &call_removeEventListener,
        .call_throwIfAborted = &call_throwIfAborted,
        .call_timeout = &call_timeout,
        .call_when = &call_when,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        AbortSignalImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        AbortSignalImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_aborted(instance: *runtime.Instance) anyerror!bool {
        return try AbortSignalImpl.get_aborted(instance);
    }

    pub fn get_reason(instance: *runtime.Instance) anyerror!anyopaque {
        return try AbortSignalImpl.get_reason(instance);
    }

    pub fn get_onabort(instance: *runtime.Instance) anyerror!EventHandler {
        return try AbortSignalImpl.get_onabort(instance);
    }

    pub fn set_onabort(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try AbortSignalImpl.set_onabort(instance, value);
    }

    /// Extended attributes: [NewObject]
    pub fn call__any(instance: *runtime.Instance, signals: anyopaque) anyerror!AbortSignal {
        // [NewObject] - Caller owns the returned object
        
        return try AbortSignalImpl.call__any(instance, signals);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try AbortSignalImpl.call_when(instance, type_, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_abort(instance: *runtime.Instance, reason: anyopaque) anyerror!AbortSignal {
        // [NewObject] - Caller owns the returned object
        
        return try AbortSignalImpl.call_abort(instance, reason);
    }

    /// Extended attributes: [Exposed=(Window,Worker)], [NewObject]
    pub fn call_timeout(instance: *runtime.Instance, milliseconds: u64) anyerror!AbortSignal {
        // [NewObject] - Caller owns the returned object
        // [EnforceRange] on milliseconds
        if (!runtime.isInRange(milliseconds)) return error.TypeError;
        
        return try AbortSignalImpl.call_timeout(instance, milliseconds);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try AbortSignalImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_throwIfAborted(instance: *runtime.Instance) anyerror!void {
        return try AbortSignalImpl.call_throwIfAborted(instance);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try AbortSignalImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try AbortSignalImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
