//! Generated from: credential-management.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CredentialImpl = @import("impls").Credential;
const mixins = @import("mixins");
const USVString = @import("interfaces").USVString;
const DOMString = @import("typedefs").DOMString;

pub const Credential = struct {
    pub const Meta = struct {
        pub const name = "Credential";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "id", "get_id", null },
            .{ "type", "get_type", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "isConditionalMediationAvailable", "call_static_isConditionalMediationAvailable", 0 },
            .{ "willRequestConditionalCreation", "call_static_willRequestConditionalCreation", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "isConditionalMediationAvailable",
            "willRequestConditionalCreation",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "id", "get_id", null },
            .{ "type", "get_type", null },
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
            id: runtime.USVString = undefined,
            @"type": runtime.DOMString = undefined,
            _internal: ?*CredentialImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_id = &get_id,
        .get_type = &get_type,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CredentialImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return CredentialImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CredentialImpl.deinit(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try CredentialImpl.get_id(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!DOMString {
        return try CredentialImpl.get_type(instance);
    }

    pub fn call_static_willRequestConditionalCreation(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try CredentialImpl.call_static_willRequestConditionalCreation(instance);
    }

    pub fn call_static_isConditionalMediationAvailable(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try CredentialImpl.call_static_isConditionalMediationAvailable(instance);
    }

};
