//! Generated from: webxr-depth-sensing.idl
//! Generated at: 2025-12-07T20:02:44Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const XRCPUDepthInformationImpl = @import("impls").XRCPUDepthInformation;
const mixins = @import("mixins");
const XRDepthInformation = @import("interfaces").XRDepthInformation;
const XRRigidTransform = @import("interfaces").XRRigidTransform;

pub const XRCPUDepthInformation = struct {
    pub const Meta = struct {
        pub const name = "XRCPUDepthInformation";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = XRDepthInformation.State;
        pub const ParentInterface = XRDepthInformation;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "data", "get_data", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getDepthInMeters", "call_getDepthInMeters", 2 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getDepthInMeters",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "data", "get_data", null },
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
            data: runtime.ArrayBuffer = undefined,
            cached_data: ?runtime.ArrayBuffer = null,
            _internal: ?*XRCPUDepthInformationImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_data = &get_data,

        .call_getDepthInMeters = &call_getDepthInMeters,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return XRCPUDepthInformationImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRCPUDepthInformationImpl.deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_data(instance: *runtime.Instance) anyerror!*const anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_data) |cached| {
            return cached;
        }
        const value = try XRCPUDepthInformationImpl.get_data(instance);
        state.own.cached_data = value;
        return value;
    }

    pub fn call_getDepthInMeters(instance: *runtime.Instance, x: f32, y: f32) anyerror!f32 {
        
        return try XRCPUDepthInformationImpl.call_getDepthInMeters(instance, x, y);
    }

};
