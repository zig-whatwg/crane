//! Generated from: fedcm.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const IdentityCredentialImpl = @import("impls").IdentityCredential;
const mixins = @import("mixins");
const Credential = @import("interfaces").Credential;
const IdentityCredentialDisconnectOptions = @import("dictionaries").IdentityCredentialDisconnectOptions;
const USVString = @import("interfaces").USVString;
const DOMString = @import("typedefs").DOMString;

pub const IdentityCredential = struct {
    pub const Meta = struct {
        pub const name = "IdentityCredential";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = Credential.State;
        pub const ParentInterface = Credential;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "token", "get_token", null },
            .{ "isAutoSelected", "get_isAutoSelected", null },
            .{ "configURL", "get_configURL", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "disconnect", "call_disconnect", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "disconnect",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "isConditionalMediationAvailable",
            "willRequestConditionalCreation",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "token", "get_token", null },
            .{ "isAutoSelected", "get_isAutoSelected", null },
            .{ "configURL", "get_configURL", null },
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
            token: runtime.JSValue = undefined,
            isAutoSelected: bool = undefined,
            configURL: runtime.USVString = undefined,
            _internal: ?*IdentityCredentialImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_configURL = &get_configURL,
        .get_isAutoSelected = &get_isAutoSelected,
        .get_token = &get_token,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return IdentityCredentialImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        IdentityCredentialImpl.deinit(instance);
    }

    pub fn get_token(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try IdentityCredentialImpl.get_token(instance);
    }

    pub fn get_isAutoSelected(instance: *runtime.Instance) anyerror!bool {
        return try IdentityCredentialImpl.get_isAutoSelected(instance);
    }

    pub fn get_configURL(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try IdentityCredentialImpl.get_configURL(instance);
    }

    pub fn call_disconnect(instance: *runtime.Instance, options: IdentityCredentialDisconnectOptions) anyerror!*const anyopaque {
        
        return try IdentityCredentialImpl.call_disconnect(instance, options);
    }

};
