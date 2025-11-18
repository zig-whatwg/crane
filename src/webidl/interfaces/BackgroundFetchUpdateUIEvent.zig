//! Generated from: background-fetch.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BackgroundFetchUpdateUIEventImpl = @import("impls").BackgroundFetchUpdateUIEvent;
const BackgroundFetchEvent = @import("interfaces").BackgroundFetchEvent;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const BackgroundFetchEventInit = @import("dictionaries").BackgroundFetchEventInit;
const BackgroundFetchUIOptions = @import("dictionaries").BackgroundFetchUIOptions;

pub const BackgroundFetchUpdateUIEvent = struct {
    pub const Meta = struct {
        pub const name = "BackgroundFetchUpdateUIEvent";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *BackgroundFetchEvent;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "ServiceWorker" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .ServiceWorker = true };
        
        /// Properties that cannot be shadowed or deleted (configurable: false)
        pub const legacy_unforgeable_properties = .{
            "isTrusted",
        };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(BackgroundFetchUpdateUIEvent, .{
        .deinit_fn = &deinit_wrapper,

        .get_AT_TARGET = &BackgroundFetchEvent.get_AT_TARGET,
        .get_BUBBLING_PHASE = &BackgroundFetchEvent.get_BUBBLING_PHASE,
        .get_CAPTURING_PHASE = &BackgroundFetchEvent.get_CAPTURING_PHASE,
        .get_NONE = &BackgroundFetchEvent.get_NONE,
        .get_bubbles = &get_bubbles,
        .get_cancelBubble = &get_cancelBubble,
        .get_cancelable = &get_cancelable,
        .get_composed = &get_composed,
        .get_currentTarget = &get_currentTarget,
        .get_defaultPrevented = &get_defaultPrevented,
        .get_eventPhase = &get_eventPhase,
        .get_isTrusted = &get_isTrusted,
        .get_registration = &get_registration,
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
        .call_updateUI = &call_updateUI,
        .call_waitUntil = &call_waitUntil,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        BackgroundFetchUpdateUIEventImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BackgroundFetchUpdateUIEventImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, type_: DOMString, init: BackgroundFetchEventInit) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try BackgroundFetchUpdateUIEventImpl.constructor(instance, type_, init);
        
        return instance;
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!DOMString {
        return try BackgroundFetchUpdateUIEventImpl.get_type(instance);
    }

    pub fn get_target(instance: *runtime.Instance) anyerror!anyopaque {
        return try BackgroundFetchUpdateUIEventImpl.get_target(instance);
    }

    pub fn get_srcElement(instance: *runtime.Instance) anyerror!anyopaque {
        return try BackgroundFetchUpdateUIEventImpl.get_srcElement(instance);
    }

    pub fn get_currentTarget(instance: *runtime.Instance) anyerror!anyopaque {
        return try BackgroundFetchUpdateUIEventImpl.get_currentTarget(instance);
    }

    pub fn get_eventPhase(instance: *runtime.Instance) anyerror!u16 {
        return try BackgroundFetchUpdateUIEventImpl.get_eventPhase(instance);
    }

    pub fn get_cancelBubble(instance: *runtime.Instance) anyerror!bool {
        return try BackgroundFetchUpdateUIEventImpl.get_cancelBubble(instance);
    }

    pub fn set_cancelBubble(instance: *runtime.Instance, value: bool) anyerror!void {
        try BackgroundFetchUpdateUIEventImpl.set_cancelBubble(instance, value);
    }

    pub fn get_bubbles(instance: *runtime.Instance) anyerror!bool {
        return try BackgroundFetchUpdateUIEventImpl.get_bubbles(instance);
    }

    pub fn get_cancelable(instance: *runtime.Instance) anyerror!bool {
        return try BackgroundFetchUpdateUIEventImpl.get_cancelable(instance);
    }

    pub fn get_returnValue(instance: *runtime.Instance) anyerror!bool {
        return try BackgroundFetchUpdateUIEventImpl.get_returnValue(instance);
    }

    pub fn set_returnValue(instance: *runtime.Instance, value: bool) anyerror!void {
        try BackgroundFetchUpdateUIEventImpl.set_returnValue(instance, value);
    }

    pub fn get_defaultPrevented(instance: *runtime.Instance) anyerror!bool {
        return try BackgroundFetchUpdateUIEventImpl.get_defaultPrevented(instance);
    }

    pub fn get_composed(instance: *runtime.Instance) anyerror!bool {
        return try BackgroundFetchUpdateUIEventImpl.get_composed(instance);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn get_isTrusted(instance: *runtime.Instance) anyerror!bool {
        return try BackgroundFetchUpdateUIEventImpl.get_isTrusted(instance);
    }

    pub fn get_timeStamp(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try BackgroundFetchUpdateUIEventImpl.get_timeStamp(instance);
    }

    pub fn get_registration(instance: *runtime.Instance) anyerror!BackgroundFetchRegistration {
        return try BackgroundFetchUpdateUIEventImpl.get_registration(instance);
    }

    pub fn call_stopImmediatePropagation(instance: *runtime.Instance) anyerror!void {
        return try BackgroundFetchUpdateUIEventImpl.call_stopImmediatePropagation(instance);
    }

    pub fn call_initEvent(instance: *runtime.Instance, type_: DOMString, bubbles: bool, cancelable: bool) anyerror!void {
        
        return try BackgroundFetchUpdateUIEventImpl.call_initEvent(instance, type_, bubbles, cancelable);
    }

    pub fn call_waitUntil(instance: *runtime.Instance, f: anyopaque) anyerror!void {
        
        return try BackgroundFetchUpdateUIEventImpl.call_waitUntil(instance, f);
    }

    pub fn call_updateUI(instance: *runtime.Instance, options: BackgroundFetchUIOptions) anyerror!anyopaque {
        
        return try BackgroundFetchUpdateUIEventImpl.call_updateUI(instance, options);
    }

    pub fn call_composedPath(instance: *runtime.Instance) anyerror!anyopaque {
        return try BackgroundFetchUpdateUIEventImpl.call_composedPath(instance);
    }

    pub fn call_stopPropagation(instance: *runtime.Instance) anyerror!void {
        return try BackgroundFetchUpdateUIEventImpl.call_stopPropagation(instance);
    }

    pub fn call_preventDefault(instance: *runtime.Instance) anyerror!void {
        return try BackgroundFetchUpdateUIEventImpl.call_preventDefault(instance);
    }

};
