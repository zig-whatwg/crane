//! Generated from: webxr-hit-test.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRRayImpl = @import("impls").XRRay;
const DOMPointInit = @import("dictionaries").DOMPointInit;
const XRRigidTransform = @import("interfaces").XRRigidTransform;
const Float32Array = @import("interfaces").Float32Array;
const XRRayDirectionInit = @import("dictionaries").XRRayDirectionInit;
const DOMPointReadOnly = @import("interfaces").DOMPointReadOnly;

pub const XRRay = struct {
    pub const Meta = struct {
        pub const name = "XRRay";
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
            origin: DOMPointReadOnly = undefined,
            direction: DOMPointReadOnly = undefined,
            matrix: Float32Array = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(XRRay, .{
        .deinit_fn = &deinit_wrapper,

        .get_direction = &get_direction,
        .get_matrix = &get_matrix,
        .get_origin = &get_origin,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        XRRayImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRRayImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, origin: DOMPointInit, direction: XRRayDirectionInit) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try XRRayImpl.constructor(instance, origin, direction);
        
        return instance;
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, transform: XRRigidTransform) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try XRRayImpl.constructor(instance, transform);
        
        return instance;
    }

    /// Extended attributes: [SameObject]
    pub fn get_origin(instance: *runtime.Instance) anyerror!DOMPointReadOnly {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_origin) |cached| {
            return cached;
        }
        const value = try XRRayImpl.get_origin(instance);
        state.cached_origin = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_direction(instance: *runtime.Instance) anyerror!DOMPointReadOnly {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_direction) |cached| {
            return cached;
        }
        const value = try XRRayImpl.get_direction(instance);
        state.cached_direction = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_matrix(instance: *runtime.Instance) anyerror!anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_matrix) |cached| {
            return cached;
        }
        const value = try XRRayImpl.get_matrix(instance);
        state.cached_matrix = value;
        return value;
    }

};
