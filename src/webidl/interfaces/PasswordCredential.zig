//! Generated from: credential-management.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PasswordCredentialImpl = @import("impls").PasswordCredential;
const Credential = @import("interfaces").Credential;
const CredentialUserData = @import("interfaces").CredentialUserData;
const PasswordCredentialData = @import("dictionaries").PasswordCredentialData;
const HTMLFormElement = @import("interfaces").HTMLFormElement;

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
        
        // Initialize the instance (Impl receives full instance)
        PasswordCredentialImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PasswordCredentialImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, form: HTMLFormElement) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try PasswordCredentialImpl.constructor(instance, form);
        
        return instance;
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, data: PasswordCredentialData) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try PasswordCredentialImpl.constructor(instance, data);
        
        return instance;
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try PasswordCredentialImpl.get_id(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!DOMString {
        return try PasswordCredentialImpl.get_type(instance);
    }

    pub fn get_password(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try PasswordCredentialImpl.get_password(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try PasswordCredentialImpl.get_name(instance);
    }

    pub fn get_iconURL(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try PasswordCredentialImpl.get_iconURL(instance);
    }

    pub fn call_willRequestConditionalCreation(instance: *runtime.Instance) anyerror!anyopaque {
        return try PasswordCredentialImpl.call_willRequestConditionalCreation(instance);
    }

    pub fn call_isConditionalMediationAvailable(instance: *runtime.Instance) anyerror!anyopaque {
        return try PasswordCredentialImpl.call_isConditionalMediationAvailable(instance);
    }

};
