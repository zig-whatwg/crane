//! Generated from: webxr-depth-sensing.idl
//! Generated at: 2025-11-29T02:15:46Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const XRDepthInformationImpl = @import("impls").XRDepthInformation;
const mixins = @import("mixins");
const XRViewGeometry = @import("interfaces").XRViewGeometry;
const XRRigidTransform = @import("interfaces").XRRigidTransform;

pub const XRDepthInformation = struct {
    pub const Meta = struct {
        pub const name = "XRDepthInformation";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{
            XRViewGeometry,
        };
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "width", "get_width", null },
            .{ "height", "get_height", null },
            .{ "normDepthBufferFromNormView", "get_normDepthBufferFromNormView", null },
            .{ "rawValueToMeters", "get_rawValueToMeters", null },
            .{ "projectionMatrix", "get_projectionMatrix", null },
            .{ "transform", "get_transform", null },
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
            .{ "width", "get_width", null },
            .{ "height", "get_height", null },
            .{ "normDepthBufferFromNormView", "get_normDepthBufferFromNormView", null },
            .{ "rawValueToMeters", "get_rawValueToMeters", null },
            .{ "projectionMatrix", "get_projectionMatrix", null },
            .{ "transform", "get_transform", null },
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
            width: u32 = undefined,
            height: u32 = undefined,
            normDepthBufferFromNormView: *runtime.Instance = undefined,
            rawValueToMeters: f32 = undefined,
            projectionMatrix: runtime.Float32Array = undefined,
            transform: *runtime.Instance = undefined,
            cached_normDepthBufferFromNormView: ?*runtime.Instance = null,
            cached_transform: ?*runtime.Instance = null,
            _internal: ?*XRDepthInformationImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_height = &get_height,
        .get_normDepthBufferFromNormView = &get_normDepthBufferFromNormView,
        .get_projectionMatrix = &get_projectionMatrix,
        .get_rawValueToMeters = &get_rawValueToMeters,
        .get_transform = &get_transform,
        .get_width = &get_width,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return XRDepthInformationImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRDepthInformationImpl.deinit(instance);
    }

    pub fn get_width(instance: *runtime.Instance) anyerror!u32 {
        return try XRDepthInformationImpl.get_width(instance);
    }

    pub fn get_height(instance: *runtime.Instance) anyerror!u32 {
        return try XRDepthInformationImpl.get_height(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_normDepthBufferFromNormView(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_normDepthBufferFromNormView) |cached| {
            return cached;
        }
        const value = try XRDepthInformationImpl.get_normDepthBufferFromNormView(instance);
        state.own.cached_normDepthBufferFromNormView = value;
        return value;
    }

    pub fn get_rawValueToMeters(instance: *runtime.Instance) anyerror!f32 {
        return try XRDepthInformationImpl.get_rawValueToMeters(instance);
    }

    pub fn get_projectionMatrix(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try XRDepthInformationImpl.get_projectionMatrix(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_transform(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_transform) |cached| {
            return cached;
        }
        const value = try XRDepthInformationImpl.get_transform(instance);
        state.own.cached_transform = value;
        return value;
    }

};
