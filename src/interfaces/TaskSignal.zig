//! Generated from: scheduling-apis.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const TaskSignalImpl = @import("../impls/TaskSignal.zig");
const AbortSignal = @import("AbortSignal.zig");

pub const TaskSignal = struct {
    pub const Meta = struct {
        pub const name = "TaskSignal";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *AbortSignal;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            priority: TaskPriority = undefined,
            onprioritychange: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(TaskSignal, .{
        .deinit_fn = &deinit_wrapper,

        .get_aborted = &get_aborted,
        .get_onabort = &get_onabort,
        .get_onprioritychange = &get_onprioritychange,
        .get_priority = &get_priority,
        .get_reason = &get_reason,

        .set_onabort = &set_onabort,
        .set_onprioritychange = &set_onprioritychange,

        .call__any = &call__any,
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
        TaskSignalImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        TaskSignalImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_aborted(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return TaskSignalImpl.get_aborted(state);
    }

    pub fn get_reason(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return TaskSignalImpl.get_reason(state);
    }

    pub fn get_onabort(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return TaskSignalImpl.get_onabort(state);
    }

    pub fn set_onabort(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        TaskSignalImpl.set_onabort(state, value);
    }

    pub fn get_priority(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return TaskSignalImpl.get_priority(state);
    }

    pub fn get_onprioritychange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return TaskSignalImpl.get_onprioritychange(state);
    }

    pub fn set_onprioritychange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        TaskSignalImpl.set_onprioritychange(state, value);
    }

    /// Arguments for _any (WebIDL overloading)
    pub const _anyArgs = union(enum) {
        /// _any(signals)
        sequence: anyopaque,
        /// _any(signals, init)
        sequence_TaskSignalAnyInit: struct {
            signals: anyopaque,
            init: anyopaque,
        },
    };

    pub fn call__any(instance: *runtime.Instance, args: _anyArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .sequence => |arg| return TaskSignalImpl.sequence(state, arg),
            .sequence_TaskSignalAnyInit => |a| return TaskSignalImpl.sequence_TaskSignalAnyInit(state, a.signals, a.init),
        }
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return TaskSignalImpl.call_when(state, type_, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_abort(instance: *runtime.Instance, reason: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return TaskSignalImpl.call_abort(state, reason);
    }

    /// Extended attributes: [Exposed=(Window,Worker)], [NewObject]
    pub fn call_timeout(instance: *runtime.Instance, milliseconds: u64) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        // [EnforceRange] on milliseconds
        if (milliseconds > std.math.maxInt(u53)) return error.TypeError;
        
        return TaskSignalImpl.call_timeout(state, milliseconds);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return TaskSignalImpl.call_dispatchEvent(state, event);
    }

    pub fn call_throwIfAborted(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return TaskSignalImpl.call_throwIfAborted(state);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return TaskSignalImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return TaskSignalImpl.call_removeEventListener(state, type_, callback, options);
    }

};
