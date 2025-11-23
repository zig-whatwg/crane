//! Generated from: webxr.idl
//! Generated at: 2025-11-23T01:22:14Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRRenderStateImpl = @import("impls").XRRenderState;
const XRWebGLLayer = @import("interfaces").XRWebGLLayer;
const XRLayer = @import("interfaces").XRLayer;

pub const XRRenderState = struct {
    pub const Meta = struct {
        pub const name = "XRRenderState";
        pub const is_mixin = false;
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
            .{ "depthNear", "get_depthNear", null },
            .{ "depthFar", "get_depthFar", null },
            .{ "passthroughFullyObscured", "get_passthroughFullyObscured", null },
            .{ "inlineVerticalFieldOfView", "get_inlineVerticalFieldOfView", null },
            .{ "baseLayer", "get_baseLayer", null },
            .{ "layers", "get_layers", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
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
            .{ "depthNear", "get_depthNear", null },
            .{ "depthFar", "get_depthFar", null },
            .{ "passthroughFullyObscured", "get_passthroughFullyObscured", null },
            .{ "inlineVerticalFieldOfView", "get_inlineVerticalFieldOfView", null },
            .{ "baseLayer", "get_baseLayer", null },
            .{ "layers", "get_layers", null },
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
            depthNear: f64 = undefined,
            depthFar: f64 = undefined,
            passthroughFullyObscured: ?bool = null,
            inlineVerticalFieldOfView: ?f64 = null,
            baseLayer: ?XRWebGLLayer = null,
            layers: runtime.FrozenArray(XRLayer) = undefined,
        },
    );

    const delegates = .{

        .get_baseLayer = &get_baseLayer,
        .get_depthFar = &get_depthFar,
        .get_depthNear = &get_depthNear,
        .get_inlineVerticalFieldOfView = &get_inlineVerticalFieldOfView,
        .get_layers = &get_layers,
        .get_passthroughFullyObscured = &get_passthroughFullyObscured,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return XRRenderStateImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRRenderStateImpl.deinit(instance);
    }

    pub fn get_depthNear(instance: *runtime.Instance) anyerror!f64 {
        return try XRRenderStateImpl.get_depthNear(instance);
    }

    pub fn get_depthFar(instance: *runtime.Instance) anyerror!f64 {
        return try XRRenderStateImpl.get_depthFar(instance);
    }

    pub fn get_passthroughFullyObscured(instance: *runtime.Instance) anyerror!bool {
        return try XRRenderStateImpl.get_passthroughFullyObscured(instance);
    }

    pub fn get_inlineVerticalFieldOfView(instance: *runtime.Instance) anyerror!f64 {
        return try XRRenderStateImpl.get_inlineVerticalFieldOfView(instance);
    }

    pub fn get_baseLayer(instance: *runtime.Instance) anyerror!XRWebGLLayer {
        return try XRRenderStateImpl.get_baseLayer(instance);
    }

    pub fn get_layers(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try XRRenderStateImpl.get_layers(instance);
    }

};
