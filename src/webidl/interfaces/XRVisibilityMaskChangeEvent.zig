//! Generated from: webxr.idl
//! Generated at: 2025-11-23T19:17:37Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRVisibilityMaskChangeEventImpl = @import("impls").XRVisibilityMaskChangeEvent;
const Event = @import("interfaces").Event;
const EventTarget = @import("interfaces").EventTarget;
const XRSession = @import("interfaces").XRSession;
const XRVisibilityMaskChangeEventInit = @import("dictionaries").XRVisibilityMaskChangeEventInit;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const XREye = @import("enums").XREye;
const DOMString = @import("typedefs").DOMString;

pub const XRVisibilityMaskChangeEvent = struct {
    pub const Meta = struct {
        pub const name = "XRVisibilityMaskChangeEvent";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Event;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "session", "get_session", null },
            .{ "eye", "get_eye", null },
            .{ "index", "get_index", null },
            .{ "vertices", "get_vertices", null },
            .{ "indices", "get_indices", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "composedPath",
            "stopPropagation",
            "stopImmediatePropagation",
            "preventDefault",
            "initEvent",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "session", "get_session", null },
            .{ "eye", "get_eye", null },
            .{ "index", "get_index", null },
            .{ "vertices", "get_vertices", null },
            .{ "indices", "get_indices", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            session: XRSession = undefined,
            eye: XREye = undefined,
            index: u32 = undefined,
            vertices: runtime.Float32Array = undefined,
            indices: runtime.Uint32Array = undefined,
            cached_session: ?XRSession = null,
            cached_vertices: ?runtime.Float32Array = null,
            cached_indices: ?runtime.Uint32Array = null,
            _internal: ?*XRVisibilityMaskChangeEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_eye = &get_eye,
        .get_index = &get_index,
        .get_indices = &get_indices,
        .get_session = &get_session,
        .get_vertices = &get_vertices,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return XRVisibilityMaskChangeEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRVisibilityMaskChangeEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: XRVisibilityMaskChangeEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try XRVisibilityMaskChangeEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    /// Extended attributes: [SameObject]
    pub fn get_session(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_session) |cached| {
            return cached;
        }
        const value = try XRVisibilityMaskChangeEventImpl.get_session(instance);
        state.own.cached_session = value;
        return value;
    }

    pub fn get_eye(instance: *runtime.Instance) anyerror!XREye {
        return try XRVisibilityMaskChangeEventImpl.get_eye(instance);
    }

    pub fn get_index(instance: *runtime.Instance) anyerror!u32 {
        return try XRVisibilityMaskChangeEventImpl.get_index(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_vertices(instance: *runtime.Instance) anyerror!*const anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_vertices) |cached| {
            return cached;
        }
        const value = try XRVisibilityMaskChangeEventImpl.get_vertices(instance);
        state.own.cached_vertices = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_indices(instance: *runtime.Instance) anyerror!*const anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_indices) |cached| {
            return cached;
        }
        const value = try XRVisibilityMaskChangeEventImpl.get_indices(instance);
        state.own.cached_indices = value;
        return value;
    }

};
