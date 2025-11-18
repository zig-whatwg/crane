//! Generated from: IndexedDB.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const IDBVersionChangeEventImpl = @import("impls").IDBVersionChangeEvent;
const Event = @import("interfaces").Event;
const unsigned long long = @import("interfaces").unsigned long long;
const IDBVersionChangeEventInit = @import("dictionaries").IDBVersionChangeEventInit;

pub const IDBVersionChangeEvent = struct {
    pub const Meta = struct {
        pub const name = "IDBVersionChangeEvent";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Event;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Properties that cannot be shadowed or deleted (configurable: false)
        pub const legacy_unforgeable_properties = .{
            "isTrusted",
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            oldVersion: u64 = undefined,
            newVersion: ?u64 = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(IDBVersionChangeEvent, .{
        .deinit_fn = &deinit_wrapper,

        .get_AT_TARGET = &Event.get_AT_TARGET,
        .get_BUBBLING_PHASE = &Event.get_BUBBLING_PHASE,
        .get_CAPTURING_PHASE = &Event.get_CAPTURING_PHASE,
        .get_NONE = &Event.get_NONE,
        .get_bubbles = &get_bubbles,
        .get_cancelBubble = &get_cancelBubble,
        .get_cancelable = &get_cancelable,
        .get_composed = &get_composed,
        .get_currentTarget = &get_currentTarget,
        .get_defaultPrevented = &get_defaultPrevented,
        .get_eventPhase = &get_eventPhase,
        .get_isTrusted = &get_isTrusted,
        .get_newVersion = &get_newVersion,
        .get_oldVersion = &get_oldVersion,
        .get_returnValue = &get_returnValue,
        .get_srcElement = &get_srcElement,
        .get_target = &get_target,
        .get_timeStamp = &get_timeStamp,
        .get_type = &get_type,

        .set_cancelBubble = &set_cancelBubble,
        .set_returnValue = &set_returnValue,

        .call_composedPath = &call_composedPath,
        .call_initEvent = &call_initEvent,
        .call_preventDefault = &call_preventDefault,
        .call_stopImmediatePropagation = &call_stopImmediatePropagation,
        .call_stopPropagation = &call_stopPropagation,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        IDBVersionChangeEventImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        IDBVersionChangeEventImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, type_: DOMString, eventInitDict: IDBVersionChangeEventInit) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try IDBVersionChangeEventImpl.constructor(instance, type_, eventInitDict);
        
        return instance;
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!DOMString {
        return try IDBVersionChangeEventImpl.get_type(instance);
    }

    pub fn get_target(instance: *runtime.Instance) anyerror!anyopaque {
        return try IDBVersionChangeEventImpl.get_target(instance);
    }

    pub fn get_srcElement(instance: *runtime.Instance) anyerror!anyopaque {
        return try IDBVersionChangeEventImpl.get_srcElement(instance);
    }

    pub fn get_currentTarget(instance: *runtime.Instance) anyerror!anyopaque {
        return try IDBVersionChangeEventImpl.get_currentTarget(instance);
    }

    pub fn get_eventPhase(instance: *runtime.Instance) anyerror!u16 {
        return try IDBVersionChangeEventImpl.get_eventPhase(instance);
    }

    pub fn get_cancelBubble(instance: *runtime.Instance) anyerror!bool {
        return try IDBVersionChangeEventImpl.get_cancelBubble(instance);
    }

    pub fn set_cancelBubble(instance: *runtime.Instance, value: bool) anyerror!void {
        try IDBVersionChangeEventImpl.set_cancelBubble(instance, value);
    }

    pub fn get_bubbles(instance: *runtime.Instance) anyerror!bool {
        return try IDBVersionChangeEventImpl.get_bubbles(instance);
    }

    pub fn get_cancelable(instance: *runtime.Instance) anyerror!bool {
        return try IDBVersionChangeEventImpl.get_cancelable(instance);
    }

    pub fn get_returnValue(instance: *runtime.Instance) anyerror!bool {
        return try IDBVersionChangeEventImpl.get_returnValue(instance);
    }

    pub fn set_returnValue(instance: *runtime.Instance, value: bool) anyerror!void {
        try IDBVersionChangeEventImpl.set_returnValue(instance, value);
    }

    pub fn get_defaultPrevented(instance: *runtime.Instance) anyerror!bool {
        return try IDBVersionChangeEventImpl.get_defaultPrevented(instance);
    }

    pub fn get_composed(instance: *runtime.Instance) anyerror!bool {
        return try IDBVersionChangeEventImpl.get_composed(instance);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn get_isTrusted(instance: *runtime.Instance) anyerror!bool {
        return try IDBVersionChangeEventImpl.get_isTrusted(instance);
    }

    pub fn get_timeStamp(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try IDBVersionChangeEventImpl.get_timeStamp(instance);
    }

    pub fn get_oldVersion(instance: *runtime.Instance) anyerror!u64 {
        return try IDBVersionChangeEventImpl.get_oldVersion(instance);
    }

    pub fn get_newVersion(instance: *runtime.Instance) anyerror!anyopaque {
        return try IDBVersionChangeEventImpl.get_newVersion(instance);
    }

    pub fn call_stopImmediatePropagation(instance: *runtime.Instance) anyerror!void {
        return try IDBVersionChangeEventImpl.call_stopImmediatePropagation(instance);
    }

    pub fn call_initEvent(instance: *runtime.Instance, type_: DOMString, bubbles: bool, cancelable: bool) anyerror!void {
        
        return try IDBVersionChangeEventImpl.call_initEvent(instance, type_, bubbles, cancelable);
    }

    pub fn call_composedPath(instance: *runtime.Instance) anyerror!anyopaque {
        return try IDBVersionChangeEventImpl.call_composedPath(instance);
    }

    pub fn call_stopPropagation(instance: *runtime.Instance) anyerror!void {
        return try IDBVersionChangeEventImpl.call_stopPropagation(instance);
    }

    pub fn call_preventDefault(instance: *runtime.Instance) anyerror!void {
        return try IDBVersionChangeEventImpl.call_preventDefault(instance);
    }

};
