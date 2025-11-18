//! Generated from: credential-management.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PasswordCredentialImpl = @import("../impls/PasswordCredential.zig");
const Credential = @import("Credential.zig");
const CredentialUserData = @import("CredentialUserData.zig");

pub const PasswordCredential = struct {
    pub const Meta = struct {
        pub const name = "PasswordCredential";
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
            password: runtime.USVString = undefined,
            name: runtime.USVString = undefined,
            iconURL: runtime.USVString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(PasswordCredential, .{
        .deinit_fn = &deinit_wrapper,

        .get_iconURL = &get_iconURL,
        .get_id = &get_id,
        .get_name = &get_name,
        .get_password = &get_password,
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
        PasswordCredentialImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        PasswordCredentialImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, form: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try PasswordCredentialImpl.constructor(state, form);
        
        return instance;
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, data: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try PasswordCredentialImpl.constructor(state, data);
        
        return instance;
    }

    pub fn get_id(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return PasswordCredentialImpl.get_id(state);
    }

    pub fn get_type(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return PasswordCredentialImpl.get_type(state);
    }

    pub fn get_password(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return PasswordCredentialImpl.get_password(state);
    }

    pub fn get_name(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return PasswordCredentialImpl.get_name(state);
    }

    pub fn get_iconURL(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return PasswordCredentialImpl.get_iconURL(state);
    }

    pub fn call_willRequestConditionalCreation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PasswordCredentialImpl.call_willRequestConditionalCreation(state);
    }

    pub fn call_isConditionalMediationAvailable(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PasswordCredentialImpl.call_isConditionalMediationAvailable(state);
    }

};
