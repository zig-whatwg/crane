//! Generated from: digital-credentials.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DigitalCredentialImpl = @import("../impls/DigitalCredential.zig");
const Credential = @import("Credential.zig");

pub const DigitalCredential = struct {
    pub const Meta = struct {
        pub const name = "DigitalCredential";
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
            protocol: runtime.DOMString = undefined,
            data: anyopaque = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(DigitalCredential, .{
        .deinit_fn = &deinit_wrapper,

        .get_data = &get_data,
        .get_id = &get_id,
        .get_protocol = &get_protocol,
        .get_type = &get_type,

        .call_isConditionalMediationAvailable = &call_isConditionalMediationAvailable,
        .call_toJSON = &call_toJSON,
        .call_userAgentAllowsProtocol = &call_userAgentAllowsProtocol,
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
        DigitalCredentialImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        DigitalCredentialImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_id(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return DigitalCredentialImpl.get_id(state);
    }

    pub fn get_type(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return DigitalCredentialImpl.get_type(state);
    }

    pub fn get_protocol(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return DigitalCredentialImpl.get_protocol(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_data(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_data) |cached| {
            return cached;
        }
        const value = DigitalCredentialImpl.get_data(state);
        state.cached_data = value;
        return value;
    }

    pub fn call_willRequestConditionalCreation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DigitalCredentialImpl.call_willRequestConditionalCreation(state);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DigitalCredentialImpl.call_toJSON(state);
    }

    pub fn call_userAgentAllowsProtocol(instance: *runtime.Instance, protocol: runtime.DOMString) bool {
        const state = instance.getState(State);
        
        return DigitalCredentialImpl.call_userAgentAllowsProtocol(state, protocol);
    }

    pub fn call_isConditionalMediationAvailable(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DigitalCredentialImpl.call_isConditionalMediationAvailable(state);
    }

};
