//! Generated from: credential-management.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const FederatedCredentialImpl = @import("../impls/FederatedCredential.zig");
const Credential = @import("Credential.zig");
const CredentialUserData = @import("CredentialUserData.zig");

pub const FederatedCredential = struct {
    pub const Meta = struct {
        pub const name = "FederatedCredential";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Credential;
        pub const MixinTypes = .{
            CredentialUserData,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            provider: runtime.USVString = undefined,
            protocol: ?runtime.DOMString = null,
            name: runtime.USVString = undefined,
            iconURL: runtime.USVString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(FederatedCredential, .{
        .deinit_fn = &deinit_wrapper,

        .get_iconURL = &get_iconURL,
        .get_id = &get_id,
        .get_name = &get_name,
        .get_protocol = &get_protocol,
        .get_provider = &get_provider,
        .get_type = &get_type,

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
        FederatedCredentialImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        FederatedCredentialImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, data: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try FederatedCredentialImpl.constructor(state, data);
        
        return instance;
    }

    pub fn get_id(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return FederatedCredentialImpl.get_id(state);
    }

    pub fn get_type(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return FederatedCredentialImpl.get_type(state);
    }

    pub fn get_provider(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return FederatedCredentialImpl.get_provider(state);
    }

    pub fn get_protocol(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FederatedCredentialImpl.get_protocol(state);
    }

    pub fn get_name(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return FederatedCredentialImpl.get_name(state);
    }

    pub fn get_iconURL(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return FederatedCredentialImpl.get_iconURL(state);
    }

    pub fn call_willRequestConditionalCreation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FederatedCredentialImpl.call_willRequestConditionalCreation(state);
    }

    pub fn call_isConditionalMediationAvailable(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FederatedCredentialImpl.call_isConditionalMediationAvailable(state);
    }

};
