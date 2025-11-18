//! Generated from: credential-management.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CredentialImpl = @import("../impls/Credential.zig");

pub const Credential = struct {
    pub const Meta = struct {
        pub const name = "Credential";
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
        struct {
            id: runtime.USVString = undefined,
            type: runtime.DOMString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Credential, .{
        .deinit_fn = &deinit_wrapper,

        .get_id = &get_id,
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
        CredentialImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CredentialImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_id(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return CredentialImpl.get_id(state);
    }

    pub fn get_type(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return CredentialImpl.get_type(state);
    }

    pub fn call_willRequestConditionalCreation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CredentialImpl.call_willRequestConditionalCreation(state);
    }

    pub fn call_isConditionalMediationAvailable(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CredentialImpl.call_isConditionalMediationAvailable(state);
    }

};
