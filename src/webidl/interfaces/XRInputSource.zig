//! Generated from: webxr.idl
//! Generated at: 2025-11-25T20:02:33Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRInputSourceImpl = @import("impls").XRInputSource;
const XRHandedness = @import("enums").XRHandedness;
const Gamepad = @import("interfaces").Gamepad;
const XRSpace = @import("interfaces").XRSpace;
const XRHand = @import("interfaces").XRHand;
const XRTargetRayMode = @import("enums").XRTargetRayMode;
const DOMString = @import("typedefs").DOMString;

pub const XRInputSource = struct {
    pub const Meta = struct {
        pub const name = "XRInputSource";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "handedness", "get_handedness", null },
            .{ "targetRayMode", "get_targetRayMode", null },
            .{ "targetRaySpace", "get_targetRaySpace", null },
            .{ "gripSpace", "get_gripSpace", null },
            .{ "profiles", "get_profiles", null },
            .{ "skipRendering", "get_skipRendering", null },
            .{ "gamepad", "get_gamepad", null },
            .{ "hand", "get_hand", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "handedness", "get_handedness", null },
            .{ "targetRayMode", "get_targetRayMode", null },
            .{ "targetRaySpace", "get_targetRaySpace", null },
            .{ "gripSpace", "get_gripSpace", null },
            .{ "profiles", "get_profiles", null },
            .{ "skipRendering", "get_skipRendering", null },
            .{ "gamepad", "get_gamepad", null },
            .{ "hand", "get_hand", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            handedness: XRHandedness = undefined,
            targetRayMode: XRTargetRayMode = undefined,
            targetRaySpace: *runtime.Instance = undefined,
            gripSpace: ?*runtime.Instance = null,
            profiles: runtime.FrozenArray(runtime.DOMString) = undefined,
            skipRendering: bool = undefined,
            gamepad: ?*runtime.Instance = null,
            hand: ?*runtime.Instance = null,
            cached_targetRaySpace: ?*runtime.Instance = null,
            cached_gripSpace: ?*runtime.Instance = null,
            cached_profiles: ?runtime.FrozenArray(runtime.DOMString) = null,
            cached_gamepad: ?*runtime.Instance = null,
            cached_hand: ?*runtime.Instance = null,
            _internal: ?*XRInputSourceImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_gamepad = &get_gamepad,
        .get_gripSpace = &get_gripSpace,
        .get_hand = &get_hand,
        .get_handedness = &get_handedness,
        .get_profiles = &get_profiles,
        .get_skipRendering = &get_skipRendering,
        .get_targetRayMode = &get_targetRayMode,
        .get_targetRaySpace = &get_targetRaySpace,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return XRInputSourceImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRInputSourceImpl.deinit(instance);
    }

    pub fn get_handedness(instance: *runtime.Instance) anyerror!XRHandedness {
        return try XRInputSourceImpl.get_handedness(instance);
    }

    pub fn get_targetRayMode(instance: *runtime.Instance) anyerror!XRTargetRayMode {
        return try XRInputSourceImpl.get_targetRayMode(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_targetRaySpace(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_targetRaySpace) |cached| {
            return cached;
        }
        const value = try XRInputSourceImpl.get_targetRaySpace(instance);
        state.own.cached_targetRaySpace = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_gripSpace(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_gripSpace) |cached| {
            return cached;
        }
        const value = try XRInputSourceImpl.get_gripSpace(instance);
        state.own.cached_gripSpace = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_profiles(instance: *runtime.Instance) anyerror!*const anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_profiles) |cached| {
            return cached;
        }
        const value = try XRInputSourceImpl.get_profiles(instance);
        state.own.cached_profiles = value;
        return value;
    }

    pub fn get_skipRendering(instance: *runtime.Instance) anyerror!bool {
        return try XRInputSourceImpl.get_skipRendering(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_gamepad(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_gamepad) |cached| {
            return cached;
        }
        const value = try XRInputSourceImpl.get_gamepad(instance);
        state.own.cached_gamepad = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_hand(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_hand) |cached| {
            return cached;
        }
        const value = try XRInputSourceImpl.get_hand(instance);
        state.own.cached_hand = value;
        return value;
    }

};
