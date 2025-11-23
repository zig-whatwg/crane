//! Generated from: webxrlayers.idl
//! Generated at: 2025-11-23T01:22:15Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRMediaBindingImpl = @import("impls").XRMediaBinding;
const HTMLVideoElement = @import("interfaces").HTMLVideoElement;
const XRMediaCylinderLayerInit = @import("dictionaries").XRMediaCylinderLayerInit;
const XREquirectLayer = @import("interfaces").XREquirectLayer;
const XRMediaQuadLayerInit = @import("dictionaries").XRMediaQuadLayerInit;
const XRCylinderLayer = @import("interfaces").XRCylinderLayer;
const XRSession = @import("interfaces").XRSession;
const XRQuadLayer = @import("interfaces").XRQuadLayer;
const XRMediaEquirectLayerInit = @import("dictionaries").XRMediaEquirectLayerInit;

pub const XRMediaBinding = struct {
    pub const Meta = struct {
        pub const name = "XRMediaBinding";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "createQuadLayer", "call_createQuadLayer", 1 },
            .{ "createCylinderLayer", "call_createCylinderLayer", 1 },
            .{ "createEquirectLayer", "call_createEquirectLayer", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "createQuadLayer",
            "createCylinderLayer",
            "createEquirectLayer",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {},
    );

    const delegates = .{

        .call_createCylinderLayer = &call_createCylinderLayer,
        .call_createEquirectLayer = &call_createEquirectLayer,
        .call_createQuadLayer = &call_createQuadLayer,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return XRMediaBindingImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRMediaBindingImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, session: XRSession) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try XRMediaBindingImpl.call_constructor(allocator, ctx, session);
    }

    pub fn call_createCylinderLayer(instance: *runtime.Instance, video: HTMLVideoElement, init_data: XRMediaCylinderLayerInit) anyerror!XRCylinderLayer {
        
        return try XRMediaBindingImpl.call_createCylinderLayer(instance, video, init_data);
    }

    pub fn call_createQuadLayer(instance: *runtime.Instance, video: HTMLVideoElement, init_data: XRMediaQuadLayerInit) anyerror!XRQuadLayer {
        
        return try XRMediaBindingImpl.call_createQuadLayer(instance, video, init_data);
    }

    pub fn call_createEquirectLayer(instance: *runtime.Instance, video: HTMLVideoElement, init_data: XRMediaEquirectLayerInit) anyerror!XREquirectLayer {
        
        return try XRMediaBindingImpl.call_createEquirectLayer(instance, video, init_data);
    }

};
