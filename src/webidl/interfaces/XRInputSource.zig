//! Generated from: webxr.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRInputSourceImpl = @import("impls").XRInputSource;
const XRHandedness = @import("enums").XRHandedness;
const XRHand = @import("interfaces").XRHand;
const XRTargetRayMode = @import("enums").XRTargetRayMode;
const FrozenArray<DOMString> = @import("interfaces").FrozenArray<DOMString>;
const Gamepad = @import("interfaces").Gamepad;
const XRSpace = @import("interfaces").XRSpace;

pub const XRInputSource = struct {
    pub const Meta = struct {
        pub const name = "XRInputSource";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            handedness: XRHandedness = undefined,
            targetRayMode: XRTargetRayMode = undefined,
            targetRaySpace: XRSpace = undefined,
            gripSpace: ?XRSpace = null,
            profiles: FrozenArray<DOMString> = undefined,
            skipRendering: bool = undefined,
            gamepad: ?Gamepad = null,
            hand: ?XRHand = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(XRInputSource, .{
        .deinit_fn = &deinit_wrapper,

        .get_gamepad = &get_gamepad,
        .get_gripSpace = &get_gripSpace,
        .get_hand = &get_hand,
        .get_handedness = &get_handedness,
        .get_profiles = &get_profiles,
        .get_skipRendering = &get_skipRendering,
        .get_targetRayMode = &get_targetRayMode,
        .get_targetRaySpace = &get_targetRaySpace,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        XRInputSourceImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRInputSourceImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_handedness(instance: *runtime.Instance) anyerror!XRHandedness {
        return try XRInputSourceImpl.get_handedness(instance);
    }

    pub fn get_targetRayMode(instance: *runtime.Instance) anyerror!XRTargetRayMode {
        return try XRInputSourceImpl.get_targetRayMode(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_targetRaySpace(instance: *runtime.Instance) anyerror!XRSpace {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_targetRaySpace) |cached| {
            return cached;
        }
        const value = try XRInputSourceImpl.get_targetRaySpace(instance);
        state.cached_targetRaySpace = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_gripSpace(instance: *runtime.Instance) anyerror!anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_gripSpace) |cached| {
            return cached;
        }
        const value = try XRInputSourceImpl.get_gripSpace(instance);
        state.cached_gripSpace = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_profiles(instance: *runtime.Instance) anyerror!anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_profiles) |cached| {
            return cached;
        }
        const value = try XRInputSourceImpl.get_profiles(instance);
        state.cached_profiles = value;
        return value;
    }

    pub fn get_skipRendering(instance: *runtime.Instance) anyerror!bool {
        return try XRInputSourceImpl.get_skipRendering(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_gamepad(instance: *runtime.Instance) anyerror!anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_gamepad) |cached| {
            return cached;
        }
        const value = try XRInputSourceImpl.get_gamepad(instance);
        state.cached_gamepad = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_hand(instance: *runtime.Instance) anyerror!anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_hand) |cached| {
            return cached;
        }
        const value = try XRInputSourceImpl.get_hand(instance);
        state.cached_hand = value;
        return value;
    }

};
