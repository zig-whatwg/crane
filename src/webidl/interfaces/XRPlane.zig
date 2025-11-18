//! Generated from: webxr-plane-detection.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRPlaneImpl = @import("impls").XRPlane;
const FrozenArray<DOMPointReadOnly> = @import("interfaces").FrozenArray<DOMPointReadOnly>;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const XRPlaneOrientation = @import("enums").XRPlaneOrientation;
const DOMString = @import("typedefs").DOMString;
const XRSpace = @import("interfaces").XRSpace;

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
        
        // Initialize the instance (Impl receives full instance)
        XRPlaneImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRPlaneImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_planeSpace(instance: *runtime.Instance) anyerror!XRSpace {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_planeSpace) |cached| {
            return cached;
        }
        const value = try XRPlaneImpl.get_planeSpace(instance);
        state.cached_planeSpace = value;
        return value;
    }

    pub fn get_polygon(instance: *runtime.Instance) anyerror!anyopaque {
        return try XRPlaneImpl.get_polygon(instance);
    }

    pub fn get_orientation(instance: *runtime.Instance) anyerror!anyopaque {
        return try XRPlaneImpl.get_orientation(instance);
    }

    pub fn get_lastChangedTime(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try XRPlaneImpl.get_lastChangedTime(instance);
    }

    pub fn get_semanticLabel(instance: *runtime.Instance) anyerror!anyopaque {
        return try XRPlaneImpl.get_semanticLabel(instance);
    }

};
