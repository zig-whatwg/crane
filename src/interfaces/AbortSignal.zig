//! Generated from: dom.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const AbortSignalImpl = @import("../impls/AbortSignal.zig");
const EventTarget = @import("EventTarget.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        AbortSignalImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        AbortSignalImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_aborted(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return AbortSignalImpl.get_aborted(state);
    }

    pub fn get_reason(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AbortSignalImpl.get_reason(state);
    }

    pub fn get_onabort(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AbortSignalImpl.get_onabort(state);
    }

    pub fn set_onabort(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        AbortSignalImpl.set_onabort(state, value);
    }

    /// Extended attributes: [NewObject]
    pub fn call__any(instance: *runtime.Instance, signals: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return AbortSignalImpl.call__any(state, signals);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return AbortSignalImpl.call_when(state, type_, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_abort(instance: *runtime.Instance, reason: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return AbortSignalImpl.call_abort(state, reason);
    }

    /// Extended attributes: [Exposed=(Window,Worker)], [NewObject]
    pub fn call_timeout(instance: *runtime.Instance, milliseconds: u64) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        // [EnforceRange] on milliseconds
        if (milliseconds > std.math.maxInt(u53)) return error.TypeError;
        
        return AbortSignalImpl.call_timeout(state, milliseconds);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return AbortSignalImpl.call_dispatchEvent(state, event);
    }

    pub fn call_throwIfAborted(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AbortSignalImpl.call_throwIfAborted(state);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return AbortSignalImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return AbortSignalImpl.call_removeEventListener(state, type_, callback, options);
    }

};
