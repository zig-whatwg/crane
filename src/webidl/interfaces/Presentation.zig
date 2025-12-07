//! Generated from: presentation-api.idl
//! Generated at: 2025-12-07T20:02:44Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const PresentationImpl = @import("impls").Presentation;
const mixins = @import("mixins");
const PresentationRequest = @import("interfaces").PresentationRequest;
const PresentationReceiver = @import("interfaces").PresentationReceiver;

pub const Presentation = struct {
    pub const Meta = struct {
        pub const name = "Presentation";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
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
            .{ "defaultRequest", "get_defaultRequest", "set_defaultRequest" },
            .{ "receiver", "get_receiver", null },
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
            .{ "defaultRequest", "get_defaultRequest", "set_defaultRequest" },
            .{ "receiver", "get_receiver", null },
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
            defaultRequest: ?*runtime.Instance = null,
            receiver: ?*runtime.Instance = null,
            _internal: ?*PresentationImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_defaultRequest = &get_defaultRequest,
        .get_receiver = &get_receiver,

        .set_defaultRequest = &set_defaultRequest,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PresentationImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PresentationImpl.deinit(instance);
    }

    pub fn get_defaultRequest(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try PresentationImpl.get_defaultRequest(instance);
    }

    pub fn set_defaultRequest(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
        try PresentationImpl.set_defaultRequest(instance, value);
    }

    pub fn get_receiver(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try PresentationImpl.get_receiver(instance);
    }

};
