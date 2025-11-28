//! Generated from: credential-management.idl
//! Generated at: 2025-11-28T22:33:22Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CredentialsContainerImpl = @import("impls").CredentialsContainer;
const mixins = @import("mixins");
const CredentialCreationOptions = @import("dictionaries").CredentialCreationOptions;
const Credential = @import("interfaces").Credential;
const CredentialRequestOptions = @import("dictionaries").CredentialRequestOptions;

pub const CredentialsContainer = struct {
    pub const Meta = struct {
        pub const name = "CredentialsContainer";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "get", "call_get", 0 },
            .{ "store", "call_store", 1 },
            .{ "create", "call_create", 0 },
            .{ "preventSilentAccess", "call_preventSilentAccess", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "get",
            "store",
            "create",
            "preventSilentAccess",
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
        struct {
            _internal: ?*CredentialsContainerImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_create = &call_create,
        .call_get = &call_get,
        .call_preventSilentAccess = &call_preventSilentAccess,
        .call_store = &call_store,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CredentialsContainerImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CredentialsContainerImpl.deinit(instance);
    }

    pub fn call_store(instance: *runtime.Instance, credential: *runtime.Instance) anyerror!*const anyopaque {
        
        return try CredentialsContainerImpl.call_store(instance, credential);
    }

    pub fn call_get(instance: *runtime.Instance, options: webidl.Opt(CredentialRequestOptions)) anyerror!*const anyopaque {
        
        return try CredentialsContainerImpl.call_get(instance, options);
    }

    pub fn call_preventSilentAccess(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try CredentialsContainerImpl.call_preventSilentAccess(instance);
    }

    pub fn call_create(instance: *runtime.Instance, options: webidl.Opt(CredentialCreationOptions)) anyerror!*const anyopaque {
        
        return try CredentialsContainerImpl.call_create(instance, options);
    }

};
