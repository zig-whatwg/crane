//! Generated from: credential-management.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const FederatedCredentialImpl = @import("impls").FederatedCredential;
const Credential = @import("interfaces").Credential;
const CredentialUserData = @import("interfaces").CredentialUserData;
const FederatedCredentialInit = @import("dictionaries").FederatedCredentialInit;
const DOMString = @import("typedefs").DOMString;

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
        
        // Initialize the instance (Impl receives full instance)
        FederatedCredentialImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        FederatedCredentialImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, data: FederatedCredentialInit) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try FederatedCredentialImpl.constructor(instance, data);
        
        return instance;
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try FederatedCredentialImpl.get_id(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!DOMString {
        return try FederatedCredentialImpl.get_type(instance);
    }

    pub fn get_provider(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try FederatedCredentialImpl.get_provider(instance);
    }

    pub fn get_protocol(instance: *runtime.Instance) anyerror!anyopaque {
        return try FederatedCredentialImpl.get_protocol(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try FederatedCredentialImpl.get_name(instance);
    }

    pub fn get_iconURL(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try FederatedCredentialImpl.get_iconURL(instance);
    }

    pub fn call_willRequestConditionalCreation(instance: *runtime.Instance) anyerror!anyopaque {
        return try FederatedCredentialImpl.call_willRequestConditionalCreation(instance);
    }

    pub fn call_isConditionalMediationAvailable(instance: *runtime.Instance) anyerror!anyopaque {
        return try FederatedCredentialImpl.call_isConditionalMediationAvailable(instance);
    }

};
