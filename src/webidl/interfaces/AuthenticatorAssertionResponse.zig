//! Generated from: webauthn.idl
//! Generated at: 2025-11-28T19:51:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const AuthenticatorAssertionResponseImpl = @import("impls").AuthenticatorAssertionResponse;
const mixins = @import("mixins");
const AuthenticatorResponse = @import("interfaces").AuthenticatorResponse;

pub const AuthenticatorAssertionResponse = struct {
    pub const Meta = struct {
        pub const name = "AuthenticatorAssertionResponse";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *AuthenticatorResponse;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "authenticatorData", "get_authenticatorData", null },
            .{ "signature", "get_signature", null },
            .{ "userHandle", "get_userHandle", null },
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
            .{ "authenticatorData", "get_authenticatorData", null },
            .{ "signature", "get_signature", null },
            .{ "userHandle", "get_userHandle", null },
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
            authenticatorData: runtime.ArrayBuffer = undefined,
            signature: runtime.ArrayBuffer = undefined,
            userHandle: ?runtime.ArrayBuffer = null,
            cached_authenticatorData: ?runtime.ArrayBuffer = null,
            cached_signature: ?runtime.ArrayBuffer = null,
            cached_userHandle: ?runtime.ArrayBuffer = null,
            _internal: ?*AuthenticatorAssertionResponseImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_authenticatorData = &get_authenticatorData,
        .get_signature = &get_signature,
        .get_userHandle = &get_userHandle,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return AuthenticatorAssertionResponseImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        AuthenticatorAssertionResponseImpl.deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_authenticatorData(instance: *runtime.Instance) anyerror!*const anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_authenticatorData) |cached| {
            return cached;
        }
        const value = try AuthenticatorAssertionResponseImpl.get_authenticatorData(instance);
        state.own.cached_authenticatorData = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_signature(instance: *runtime.Instance) anyerror!*const anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_signature) |cached| {
            return cached;
        }
        const value = try AuthenticatorAssertionResponseImpl.get_signature(instance);
        state.own.cached_signature = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_userHandle(instance: *runtime.Instance) anyerror!?*const anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_userHandle) |cached| {
            return cached;
        }
        const value = try AuthenticatorAssertionResponseImpl.get_userHandle(instance);
        state.own.cached_userHandle = value;
        return value;
    }

};
