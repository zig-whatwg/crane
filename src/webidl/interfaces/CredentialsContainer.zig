//! Generated from: credential-management.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CredentialsContainerImpl = @import("impls").CredentialsContainer;
const Promise<Credential?> = @import("interfaces").Promise<Credential?>;
const CredentialCreationOptions = @import("dictionaries").CredentialCreationOptions;
const Credential = @import("interfaces").Credential;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const CredentialRequestOptions = @import("dictionaries").CredentialRequestOptions;

pub const CredentialsContainer = struct {
    pub const Meta = struct {
        pub const name = "CredentialsContainer";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CredentialsContainer, .{
        .deinit_fn = &deinit_wrapper,

        .call_create = &call_create,
        .call_get = &call_get,
        .call_preventSilentAccess = &call_preventSilentAccess,
        .call_store = &call_store,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        CredentialsContainerImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CredentialsContainerImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_store(instance: *runtime.Instance, credential: Credential) anyerror!anyopaque {
        
        return try CredentialsContainerImpl.call_store(instance, credential);
    }

    pub fn call_get(instance: *runtime.Instance, options: CredentialRequestOptions) anyerror!anyopaque {
        
        return try CredentialsContainerImpl.call_get(instance, options);
    }

    pub fn call_preventSilentAccess(instance: *runtime.Instance) anyerror!anyopaque {
        return try CredentialsContainerImpl.call_preventSilentAccess(instance);
    }

    pub fn call_create(instance: *runtime.Instance, options: CredentialCreationOptions) anyerror!anyopaque {
        
        return try CredentialsContainerImpl.call_create(instance, options);
    }

};
