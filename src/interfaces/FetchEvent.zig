//! Generated from: service-workers.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const FetchEventImpl = @import("../impls/FetchEvent.zig");
const ExtendableEvent = @import("ExtendableEvent.zig");

pub const FetchEvent = struct {
    pub const Meta = struct {
        pub const name = "FetchEvent";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *ExtendableEvent;
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
        struct {
            request: Request = undefined,
            preloadResponse: Promise<any> = undefined,
            clientId: runtime.DOMString = undefined,
            resultingClientId: runtime.DOMString = undefined,
            replacesClientId: runtime.DOMString = undefined,
            handled: Promise<undefined> = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(FetchEvent, .{
        .deinit_fn = &deinit_wrapper,

        .get_AT_TARGET = &ExtendableEvent.get_AT_TARGET,
        .get_BUBBLING_PHASE = &ExtendableEvent.get_BUBBLING_PHASE,
        .get_CAPTURING_PHASE = &ExtendableEvent.get_CAPTURING_PHASE,
        .get_NONE = &ExtendableEvent.get_NONE,
        .get_bubbles = &get_bubbles,
        .get_cancelBubble = &get_cancelBubble,
        .get_cancelable = &get_cancelable,
        .get_clientId = &get_clientId,
        .get_composed = &get_composed,
        .get_currentTarget = &get_currentTarget,
        .get_defaultPrevented = &get_defaultPrevented,
        .get_eventPhase = &get_eventPhase,
        .get_handled = &get_handled,
        .get_isTrusted = &get_isTrusted,
        .get_preloadResponse = &get_preloadResponse,
        .get_replacesClientId = &get_replacesClientId,
        .get_request = &get_request,
        .get_resultingClientId = &get_resultingClientId,
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
        .call_respondWith = &call_respondWith,
        .call_stopImmediatePropagation = &call_stopImmediatePropagation,
        .call_stopPropagation = &call_stopPropagation,
        .call_waitUntil = &call_waitUntil,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        FetchEventImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        FetchEventImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, type_: runtime.DOMString, eventInitDict: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try FetchEventImpl.constructor(state, type_, eventInitDict);
        
        return instance;
    }

    pub fn get_type(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return FetchEventImpl.get_type(state);
    }

    pub fn get_target(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FetchEventImpl.get_target(state);
    }

    pub fn get_srcElement(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FetchEventImpl.get_srcElement(state);
    }

    pub fn get_currentTarget(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FetchEventImpl.get_currentTarget(state);
    }

    pub fn get_eventPhase(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return FetchEventImpl.get_eventPhase(state);
    }

    pub fn get_cancelBubble(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return FetchEventImpl.get_cancelBubble(state);
    }

    pub fn set_cancelBubble(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        FetchEventImpl.set_cancelBubble(state, value);
    }

    pub fn get_bubbles(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return FetchEventImpl.get_bubbles(state);
    }

    pub fn get_cancelable(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return FetchEventImpl.get_cancelable(state);
    }

    pub fn get_returnValue(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return FetchEventImpl.get_returnValue(state);
    }

    pub fn set_returnValue(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        FetchEventImpl.set_returnValue(state, value);
    }

    pub fn get_defaultPrevented(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return FetchEventImpl.get_defaultPrevented(state);
    }

    pub fn get_composed(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return FetchEventImpl.get_composed(state);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn get_isTrusted(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return FetchEventImpl.get_isTrusted(state);
    }

    pub fn get_timeStamp(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FetchEventImpl.get_timeStamp(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_request(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_request) |cached| {
            return cached;
        }
        const value = FetchEventImpl.get_request(state);
        state.cached_request = value;
        return value;
    }

    pub fn get_preloadResponse(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FetchEventImpl.get_preloadResponse(state);
    }

    pub fn get_clientId(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return FetchEventImpl.get_clientId(state);
    }

    pub fn get_resultingClientId(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return FetchEventImpl.get_resultingClientId(state);
    }

    pub fn get_replacesClientId(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return FetchEventImpl.get_replacesClientId(state);
    }

    pub fn get_handled(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FetchEventImpl.get_handled(state);
    }

    pub fn call_stopImmediatePropagation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FetchEventImpl.call_stopImmediatePropagation(state);
    }

    pub fn call_initEvent(instance: *runtime.Instance, type_: runtime.DOMString, bubbles: bool, cancelable: bool) anyopaque {
        const state = instance.getState(State);
        
        return FetchEventImpl.call_initEvent(state, type_, bubbles, cancelable);
    }

    pub fn call_waitUntil(instance: *runtime.Instance, f: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return FetchEventImpl.call_waitUntil(state, f);
    }

    pub fn call_respondWith(instance: *runtime.Instance, r: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return FetchEventImpl.call_respondWith(state, r);
    }

    pub fn call_composedPath(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FetchEventImpl.call_composedPath(state);
    }

    pub fn call_stopPropagation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FetchEventImpl.call_stopPropagation(state);
    }

    pub fn call_preventDefault(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FetchEventImpl.call_preventDefault(state);
    }

};
