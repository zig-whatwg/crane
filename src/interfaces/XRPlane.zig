//! Generated from: webxr-plane-detection.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRPlaneImpl = @import("../impls/XRPlane.zig");

pub const XRPlane = struct {
    pub const Meta = struct {
        pub const name = "XRPlane";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {
            planeSpace: XRSpace = undefined,
            polygon: FrozenArray<DOMPointReadOnly> = undefined,
            orientation: ?XRPlaneOrientation = null,
            lastChangedTime: DOMHighResTimeStamp = undefined,
            semanticLabel: ?runtime.DOMString = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(XRPlane, .{
        .deinit_fn = &deinit_wrapper,

        .get_lastChangedTime = &get_lastChangedTime,
        .get_orientation = &get_orientation,
        .get_planeSpace = &get_planeSpace,
        .get_polygon = &get_polygon,
        .get_semanticLabel = &get_semanticLabel,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        XRPlaneImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        XRPlaneImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_planeSpace(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_planeSpace) |cached| {
            return cached;
        }
        const value = XRPlaneImpl.get_planeSpace(state);
        state.cached_planeSpace = value;
        return value;
    }

    pub fn get_polygon(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRPlaneImpl.get_polygon(state);
    }

    pub fn get_orientation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRPlaneImpl.get_orientation(state);
    }

    pub fn get_lastChangedTime(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRPlaneImpl.get_lastChangedTime(state);
    }

    pub fn get_semanticLabel(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRPlaneImpl.get_semanticLabel(state);
    }

};
