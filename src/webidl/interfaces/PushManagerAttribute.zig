//! Generated from: push-api.idl
//! Generated at: 2025-11-28T22:33:20Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PushManagerAttributeImpl = @import("impls").PushManagerAttribute;
const mixins = @import("mixins");
const PushManager = @import("interfaces").PushManager;

pub const PushManagerAttribute = struct {
    pub const Meta = struct {
        pub const name = "PushManagerAttribute";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "pushManager", "get_pushManager", null },
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
            .{ "pushManager", "get_pushManager", null },
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
            pushManager: *runtime.Instance = undefined,
            _internal: ?*PushManagerAttributeImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_pushManager = &get_pushManager,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PushManagerAttributeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PushManagerAttributeImpl.deinit(instance);
    }

    pub fn get_pushManager(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try PushManagerAttributeImpl.get_pushManager(instance);
    }

};
