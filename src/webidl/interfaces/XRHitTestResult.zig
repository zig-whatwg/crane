//! Generated from: webxr-hit-test.idl
//! Generated at: 2025-11-23T01:18:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRHitTestResultImpl = @import("impls").XRHitTestResult;
const XRPose = @import("interfaces").XRPose;
const XRAnchor = @import("interfaces").XRAnchor;
const XRSpace = @import("interfaces").XRSpace;

pub const XRHitTestResult = struct {
    pub const Meta = struct {
        pub const name = "XRHitTestResult";
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
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "getPose", "call_getPose", 1 },
            .{ "createAnchor", "call_createAnchor", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getPose",
            "createAnchor",
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
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {},
    );

    const delegates = .{

        .call_createAnchor = &call_createAnchor,
        .call_getPose = &call_getPose,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return XRHitTestResultImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRHitTestResultImpl.deinit(instance);
    }

    pub fn call_createAnchor(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try XRHitTestResultImpl.call_createAnchor(instance);
    }

    pub fn call_getPose(instance: *runtime.Instance, baseSpace: XRSpace) anyerror!XRPose {
        
        return try XRHitTestResultImpl.call_getPose(instance, baseSpace);
    }

};
