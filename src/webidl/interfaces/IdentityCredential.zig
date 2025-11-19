//! Generated from: fedcm.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const IdentityCredentialImpl = @import("impls").IdentityCredential;
const Credential = @import("interfaces").Credential;
const IdentityCredentialDisconnectOptions = @import("dictionaries").IdentityCredentialDisconnectOptions;
const USVString = @import("interfaces").USVString;
const DOMString = @import("typedefs").DOMString;

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
        return IdentityCredentialImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        IdentityCredentialImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try IdentityCredentialImpl.get_id(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!DOMString {
        return try IdentityCredentialImpl.get_type(instance);
    }

    pub fn get_token(instance: *runtime.Instance) anyerror!anyopaque {
        return try IdentityCredentialImpl.get_token(instance);
    }

    pub fn get_isAutoSelected(instance: *runtime.Instance) anyerror!bool {
        return try IdentityCredentialImpl.get_isAutoSelected(instance);
    }

    pub fn get_configURL(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try IdentityCredentialImpl.get_configURL(instance);
    }

    pub fn call_willRequestConditionalCreation(instance: *runtime.Instance) anyerror!anyopaque {
        return try IdentityCredentialImpl.call_willRequestConditionalCreation(instance);
    }

    pub fn call_disconnect(instance: *runtime.Instance, options: IdentityCredentialDisconnectOptions) anyerror!anyopaque {
        
        return try IdentityCredentialImpl.call_disconnect(instance, options);
    }

    pub fn call_isConditionalMediationAvailable(instance: *runtime.Instance) anyerror!anyopaque {
        return try IdentityCredentialImpl.call_isConditionalMediationAvailable(instance);
    }

};
