//! Generated from: webxr-depth-sensing.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRDepthInformationImpl = @import("impls").XRDepthInformation;
const XRViewGeometry = @import("interfaces").XRViewGeometry;
const XRRigidTransform = @import("interfaces").XRRigidTransform;
const Float32Array = @import("interfaces").Float32Array;

pub const XRDepthInformation = struct {
    pub const Meta = struct {
        pub const name = "XRDepthInformation";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{
            XRViewGeometry,
        };
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            width: u32 = undefined,
            height: u32 = undefined,
            normDepthBufferFromNormView: XRRigidTransform = undefined,
            rawValueToMeters: f32 = undefined,
            projectionMatrix: Float32Array = undefined,
            transform: XRRigidTransform = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(XRDepthInformation, .{
        .deinit_fn = &deinit_wrapper,

        .get_height = &get_height,
        .get_normDepthBufferFromNormView = &get_normDepthBufferFromNormView,
        .get_projectionMatrix = &get_projectionMatrix,
        .get_rawValueToMeters = &get_rawValueToMeters,
        .get_transform = &get_transform,
        .get_width = &get_width,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        XRDepthInformationImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRDepthInformationImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_width(instance: *runtime.Instance) anyerror!u32 {
        return try XRDepthInformationImpl.get_width(instance);
    }

    pub fn get_height(instance: *runtime.Instance) anyerror!u32 {
        return try XRDepthInformationImpl.get_height(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_normDepthBufferFromNormView(instance: *runtime.Instance) anyerror!XRRigidTransform {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_normDepthBufferFromNormView) |cached| {
            return cached;
        }
        const value = try XRDepthInformationImpl.get_normDepthBufferFromNormView(instance);
        state.cached_normDepthBufferFromNormView = value;
        return value;
    }

    pub fn get_rawValueToMeters(instance: *runtime.Instance) anyerror!f32 {
        return try XRDepthInformationImpl.get_rawValueToMeters(instance);
    }

    pub fn get_projectionMatrix(instance: *runtime.Instance) anyerror!anyopaque {
        return try XRDepthInformationImpl.get_projectionMatrix(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_transform(instance: *runtime.Instance) anyerror!XRRigidTransform {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_transform) |cached| {
            return cached;
        }
        const value = try XRDepthInformationImpl.get_transform(instance);
        state.cached_transform = value;
        return value;
    }

};
