//! Generated from: webauthn.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const AuthenticatorAssertionResponseImpl = @import("impls").AuthenticatorAssertionResponse;
const AuthenticatorResponse = @import("interfaces").AuthenticatorResponse;
const ArrayBuffer = @import("interfaces").ArrayBuffer;

pub const AuthenticatorAssertionResponse = struct {
    pub const Meta = struct {
        pub const name = "AuthenticatorAssertionResponse";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *AuthenticatorResponse;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            authenticatorData: ArrayBuffer = undefined,
            signature: ArrayBuffer = undefined,
            userHandle: ?ArrayBuffer = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(AuthenticatorAssertionResponse, .{
        .deinit_fn = &deinit_wrapper,

        .get_authenticatorData = &get_authenticatorData,
        .get_clientDataJSON = &get_clientDataJSON,
        .get_signature = &get_signature,
        .get_userHandle = &get_userHandle,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        AuthenticatorAssertionResponseImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        AuthenticatorAssertionResponseImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_clientDataJSON(instance: *runtime.Instance) anyerror!anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_clientDataJSON) |cached| {
            return cached;
        }
        const value = try AuthenticatorAssertionResponseImpl.get_clientDataJSON(instance);
        state.cached_clientDataJSON = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_authenticatorData(instance: *runtime.Instance) anyerror!anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_authenticatorData) |cached| {
            return cached;
        }
        const value = try AuthenticatorAssertionResponseImpl.get_authenticatorData(instance);
        state.cached_authenticatorData = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_signature(instance: *runtime.Instance) anyerror!anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_signature) |cached| {
            return cached;
        }
        const value = try AuthenticatorAssertionResponseImpl.get_signature(instance);
        state.cached_signature = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_userHandle(instance: *runtime.Instance) anyerror!anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_userHandle) |cached| {
            return cached;
        }
        const value = try AuthenticatorAssertionResponseImpl.get_userHandle(instance);
        state.cached_userHandle = value;
        return value;
    }

};
