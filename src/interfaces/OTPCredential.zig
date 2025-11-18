//! Generated from: web-otp.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const OTPCredentialImpl = @import("../impls/OTPCredential.zig");
const Credential = @import("Credential.zig");

pub const OTPCredential = struct {
    pub const Meta = struct {
        pub const name = "OTPCredential";
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
            code: runtime.DOMString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(OTPCredential, .{
        .deinit_fn = &deinit_wrapper,

        .get_code = &get_code,
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
        OTPCredentialImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        OTPCredentialImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_id(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return OTPCredentialImpl.get_id(state);
    }

    pub fn get_type(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return OTPCredentialImpl.get_type(state);
    }

    pub fn get_code(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return OTPCredentialImpl.get_code(state);
    }

    pub fn call_willRequestConditionalCreation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return OTPCredentialImpl.call_willRequestConditionalCreation(state);
    }

    pub fn call_isConditionalMediationAvailable(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return OTPCredentialImpl.call_isConditionalMediationAvailable(state);
    }

};
