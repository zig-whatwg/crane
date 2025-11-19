//! Generated from: scheduling-apis.idl
//! Generated at: 2025-11-19T20:02:00Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const TaskSignalImpl = @import("impls").TaskSignal;
const AbortSignal = @import("interfaces").AbortSignal;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const Observable = @import("interfaces").Observable;
const TaskPriority = @import("enums").TaskPriority;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const EventListener = @import("interfaces").EventListener;
const TaskSignalAnyInit = @import("dictionaries").TaskSignalAnyInit;
const EventHandler = @import("typedefs").EventHandler;

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
        return TaskSignalImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        TaskSignalImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_aborted(instance: *runtime.Instance) anyerror!bool {
        return try TaskSignalImpl.get_aborted(instance);
    }

    pub fn get_reason(instance: *runtime.Instance) anyerror!anyopaque {
        return try TaskSignalImpl.get_reason(instance);
    }

    pub fn get_onabort(instance: *runtime.Instance) anyerror!EventHandler {
        return try TaskSignalImpl.get_onabort(instance);
    }

    pub fn set_onabort(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try TaskSignalImpl.set_onabort(instance, value);
    }

    pub fn get_priority(instance: *runtime.Instance) anyerror!TaskPriority {
        return try TaskSignalImpl.get_priority(instance);
    }

    pub fn get_onprioritychange(instance: *runtime.Instance) anyerror!EventHandler {
        return try TaskSignalImpl.get_onprioritychange(instance);
    }

    pub fn set_onprioritychange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try TaskSignalImpl.set_onprioritychange(instance, value);
    }

    /// Extended attributes: [NewObject]
    pub fn call__any(instance: *runtime.Instance, signals: anyopaque) anyerror!AbortSignal {
        // [NewObject] - Caller owns the returned object
        
        return try TaskSignalImpl.call__any(instance, signals);
    }

    pub fn call_when(instance: *runtime.Instance, @"type": DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try TaskSignalImpl.call_when(instance, @"type", options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_abort(instance: *runtime.Instance, reason: anyopaque) anyerror!AbortSignal {
        // [NewObject] - Caller owns the returned object
        
        return try TaskSignalImpl.call_abort(instance, reason);
    }

    /// Extended attributes: [Exposed=(Window,Worker)], [NewObject]
    pub fn call_timeout(instance: *runtime.Instance, milliseconds: u64) anyerror!AbortSignal {
        // [NewObject] - Caller owns the returned object
        // [EnforceRange] on milliseconds
        if (!runtime.isInRange(milliseconds)) return error.TypeError;
        
        return try TaskSignalImpl.call_timeout(instance, milliseconds);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try TaskSignalImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_throwIfAborted(instance: *runtime.Instance) anyerror!void {
        return try TaskSignalImpl.call_throwIfAborted(instance);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, @"type": DOMString, callback: EventListener, options: anyopaque) anyerror!void {
        
        return try TaskSignalImpl.call_addEventListener(instance, @"type", callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, @"type": DOMString, callback: EventListener, options: anyopaque) anyerror!void {
        
        return try TaskSignalImpl.call_removeEventListener(instance, @"type", callback, options);
    }

};
