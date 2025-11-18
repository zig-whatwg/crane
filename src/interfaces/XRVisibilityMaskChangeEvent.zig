//! Generated from: webxr.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRVisibilityMaskChangeEventImpl = @import("../impls/XRVisibilityMaskChangeEvent.zig");
const Event = @import("Event.zig");

pub const XRVisibilityMaskChangeEvent = struct {
    pub const Meta = struct {
        pub const name = "XRVisibilityMaskChangeEvent";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Event;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Properties that cannot be shadowed or deleted (configurable: false)
        pub const legacy_unforgeable_properties = .{
            "isTrusted",
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            session: XRSession = undefined,
            eye: XREye = undefined,
            index: u32 = undefined,
            vertices: Float32Array = undefined,
            indices: Uint32Array = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(XRVisibilityMaskChangeEvent, .{
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
        .get_eye = &get_eye,
        .get_index = &get_index,
        .get_indices = &get_indices,
        .get_isTrusted = &get_isTrusted,
        .get_returnValue = &get_returnValue,
        .get_session = &get_session,
        .get_srcElement = &get_srcElement,
        .get_target = &get_target,
        .get_timeStamp = &get_timeStamp,
        .get_type = &get_type,
        .get_vertices = &get_vertices,

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
        
        // Initialize the state (Impl receives full hierarchy)
        XRVisibilityMaskChangeEventImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        XRVisibilityMaskChangeEventImpl.deinit(state);
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
        try XRVisibilityMaskChangeEventImpl.constructor(state, type_, eventInitDict);
        
        return instance;
    }

    pub fn get_type(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return XRVisibilityMaskChangeEventImpl.get_type(state);
    }

    pub fn get_target(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRVisibilityMaskChangeEventImpl.get_target(state);
    }

    pub fn get_srcElement(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRVisibilityMaskChangeEventImpl.get_srcElement(state);
    }

    pub fn get_currentTarget(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRVisibilityMaskChangeEventImpl.get_currentTarget(state);
    }

    pub fn get_eventPhase(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return XRVisibilityMaskChangeEventImpl.get_eventPhase(state);
    }

    pub fn get_cancelBubble(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return XRVisibilityMaskChangeEventImpl.get_cancelBubble(state);
    }

    pub fn set_cancelBubble(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        XRVisibilityMaskChangeEventImpl.set_cancelBubble(state, value);
    }

    pub fn get_bubbles(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return XRVisibilityMaskChangeEventImpl.get_bubbles(state);
    }

    pub fn get_cancelable(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return XRVisibilityMaskChangeEventImpl.get_cancelable(state);
    }

    pub fn get_returnValue(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return XRVisibilityMaskChangeEventImpl.get_returnValue(state);
    }

    pub fn set_returnValue(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        XRVisibilityMaskChangeEventImpl.set_returnValue(state, value);
    }

    pub fn get_defaultPrevented(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return XRVisibilityMaskChangeEventImpl.get_defaultPrevented(state);
    }

    pub fn get_composed(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return XRVisibilityMaskChangeEventImpl.get_composed(state);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn get_isTrusted(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return XRVisibilityMaskChangeEventImpl.get_isTrusted(state);
    }

    pub fn get_timeStamp(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRVisibilityMaskChangeEventImpl.get_timeStamp(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_session(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_session) |cached| {
            return cached;
        }
        const value = XRVisibilityMaskChangeEventImpl.get_session(state);
        state.cached_session = value;
        return value;
    }

    pub fn get_eye(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRVisibilityMaskChangeEventImpl.get_eye(state);
    }

    pub fn get_index(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return XRVisibilityMaskChangeEventImpl.get_index(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_vertices(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_vertices) |cached| {
            return cached;
        }
        const value = XRVisibilityMaskChangeEventImpl.get_vertices(state);
        state.cached_vertices = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_indices(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_indices) |cached| {
            return cached;
        }
        const value = XRVisibilityMaskChangeEventImpl.get_indices(state);
        state.cached_indices = value;
        return value;
    }

    pub fn call_stopImmediatePropagation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRVisibilityMaskChangeEventImpl.call_stopImmediatePropagation(state);
    }

    pub fn call_initEvent(instance: *runtime.Instance, type_: runtime.DOMString, bubbles: bool, cancelable: bool) anyopaque {
        const state = instance.getState(State);
        
        return XRVisibilityMaskChangeEventImpl.call_initEvent(state, type_, bubbles, cancelable);
    }

    pub fn call_composedPath(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRVisibilityMaskChangeEventImpl.call_composedPath(state);
    }

    pub fn call_stopPropagation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRVisibilityMaskChangeEventImpl.call_stopPropagation(state);
    }

    pub fn call_preventDefault(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRVisibilityMaskChangeEventImpl.call_preventDefault(state);
    }

};
