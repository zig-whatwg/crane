//! Generated from: fedcm.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const IdentityCredentialImpl = @import("../impls/IdentityCredential.zig");
const Credential = @import("Credential.zig");

pub const IdentityCredential = struct {
    pub const Meta = struct {
        pub const name = "IdentityCredential";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Credential;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            token: anyopaque = undefined,
            isAutoSelected: bool = undefined,
            configURL: runtime.USVString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(IdentityCredential, .{
        .deinit_fn = &deinit_wrapper,

        .get_configURL = &get_configURL,
        .get_id = &get_id,
        .get_isAutoSelected = &get_isAutoSelected,
        .get_token = &get_token,
        .get_type = &get_type,

        .call_disconnect = &call_disconnect,
        .call_isConditionalMediationAvailable = &call_isConditionalMediationAvailable,
        .call_willRequestConditionalCreation = &call_willRequestConditionalCreation,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        IdentityCredentialImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        IdentityCredentialImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_id(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return IdentityCredentialImpl.get_id(state);
    }

    pub fn get_type(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return IdentityCredentialImpl.get_type(state);
    }

    pub fn get_token(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return IdentityCredentialImpl.get_token(state);
    }

    pub fn get_isAutoSelected(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return IdentityCredentialImpl.get_isAutoSelected(state);
    }

    pub fn get_configURL(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return IdentityCredentialImpl.get_configURL(state);
    }

    pub fn call_willRequestConditionalCreation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return IdentityCredentialImpl.call_willRequestConditionalCreation(state);
    }

    pub fn call_disconnect(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return IdentityCredentialImpl.call_disconnect(state, options);
    }

    pub fn call_isConditionalMediationAvailable(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return IdentityCredentialImpl.call_isConditionalMediationAvailable(state);
    }

};
