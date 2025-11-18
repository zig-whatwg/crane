//! Generated from: webxr.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRVisibilityMaskChangeEventImpl = @import("impls").XRVisibilityMaskChangeEvent;
const Event = @import("interfaces").Event;
const XRSession = @import("interfaces").XRSession;
const XRVisibilityMaskChangeEventInit = @import("dictionaries").XRVisibilityMaskChangeEventInit;
const Float32Array = @import("interfaces").Float32Array;
const Uint32Array = @import("interfaces").Uint32Array;
const XREye = @import("enums").XREye;

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
        
        // Initialize the instance (Impl receives full instance)
        XRVisibilityMaskChangeEventImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRVisibilityMaskChangeEventImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, type_: DOMString, eventInitDict: XRVisibilityMaskChangeEventInit) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try XRVisibilityMaskChangeEventImpl.constructor(instance, type_, eventInitDict);
        
        return instance;
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!DOMString {
        return try XRVisibilityMaskChangeEventImpl.get_type(instance);
    }

    pub fn get_target(instance: *runtime.Instance) anyerror!anyopaque {
        return try XRVisibilityMaskChangeEventImpl.get_target(instance);
    }

    pub fn get_srcElement(instance: *runtime.Instance) anyerror!anyopaque {
        return try XRVisibilityMaskChangeEventImpl.get_srcElement(instance);
    }

    pub fn get_currentTarget(instance: *runtime.Instance) anyerror!anyopaque {
        return try XRVisibilityMaskChangeEventImpl.get_currentTarget(instance);
    }

    pub fn get_eventPhase(instance: *runtime.Instance) anyerror!u16 {
        return try XRVisibilityMaskChangeEventImpl.get_eventPhase(instance);
    }

    pub fn get_cancelBubble(instance: *runtime.Instance) anyerror!bool {
        return try XRVisibilityMaskChangeEventImpl.get_cancelBubble(instance);
    }

    pub fn set_cancelBubble(instance: *runtime.Instance, value: bool) anyerror!void {
        try XRVisibilityMaskChangeEventImpl.set_cancelBubble(instance, value);
    }

    pub fn get_bubbles(instance: *runtime.Instance) anyerror!bool {
        return try XRVisibilityMaskChangeEventImpl.get_bubbles(instance);
    }

    pub fn get_cancelable(instance: *runtime.Instance) anyerror!bool {
        return try XRVisibilityMaskChangeEventImpl.get_cancelable(instance);
    }

    pub fn get_returnValue(instance: *runtime.Instance) anyerror!bool {
        return try XRVisibilityMaskChangeEventImpl.get_returnValue(instance);
    }

    pub fn set_returnValue(instance: *runtime.Instance, value: bool) anyerror!void {
        try XRVisibilityMaskChangeEventImpl.set_returnValue(instance, value);
    }

    pub fn get_defaultPrevented(instance: *runtime.Instance) anyerror!bool {
        return try XRVisibilityMaskChangeEventImpl.get_defaultPrevented(instance);
    }

    pub fn get_composed(instance: *runtime.Instance) anyerror!bool {
        return try XRVisibilityMaskChangeEventImpl.get_composed(instance);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn get_isTrusted(instance: *runtime.Instance) anyerror!bool {
        return try XRVisibilityMaskChangeEventImpl.get_isTrusted(instance);
    }

    pub fn get_timeStamp(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try XRVisibilityMaskChangeEventImpl.get_timeStamp(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_session(instance: *runtime.Instance) anyerror!XRSession {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_session) |cached| {
            return cached;
        }
        const value = try XRVisibilityMaskChangeEventImpl.get_session(instance);
        state.cached_session = value;
        return value;
    }

    pub fn get_eye(instance: *runtime.Instance) anyerror!XREye {
        return try XRVisibilityMaskChangeEventImpl.get_eye(instance);
    }

    pub fn get_index(instance: *runtime.Instance) anyerror!u32 {
        return try XRVisibilityMaskChangeEventImpl.get_index(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_vertices(instance: *runtime.Instance) anyerror!anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_vertices) |cached| {
            return cached;
        }
        const value = try XRVisibilityMaskChangeEventImpl.get_vertices(instance);
        state.cached_vertices = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_indices(instance: *runtime.Instance) anyerror!anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_indices) |cached| {
            return cached;
        }
        const value = try XRVisibilityMaskChangeEventImpl.get_indices(instance);
        state.cached_indices = value;
        return value;
    }

    pub fn call_stopImmediatePropagation(instance: *runtime.Instance) anyerror!void {
        return try XRVisibilityMaskChangeEventImpl.call_stopImmediatePropagation(instance);
    }

    pub fn call_initEvent(instance: *runtime.Instance, type_: DOMString, bubbles: bool, cancelable: bool) anyerror!void {
        
        return try XRVisibilityMaskChangeEventImpl.call_initEvent(instance, type_, bubbles, cancelable);
    }

    pub fn call_composedPath(instance: *runtime.Instance) anyerror!anyopaque {
        return try XRVisibilityMaskChangeEventImpl.call_composedPath(instance);
    }

    pub fn call_stopPropagation(instance: *runtime.Instance) anyerror!void {
        return try XRVisibilityMaskChangeEventImpl.call_stopPropagation(instance);
    }

    pub fn call_preventDefault(instance: *runtime.Instance) anyerror!void {
        return try XRVisibilityMaskChangeEventImpl.call_preventDefault(instance);
    }

};
