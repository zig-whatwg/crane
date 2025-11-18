//! Generated from: digital-credentials.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DigitalCredentialImpl = @import("impls").DigitalCredential;
const Credential = @import("interfaces").Credential;

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
        
        // Initialize the instance (Impl receives full instance)
        DigitalCredentialImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DigitalCredentialImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try DigitalCredentialImpl.get_id(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!DOMString {
        return try DigitalCredentialImpl.get_type(instance);
    }

    pub fn get_protocol(instance: *runtime.Instance) anyerror!DOMString {
        return try DigitalCredentialImpl.get_protocol(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_data(instance: *runtime.Instance) anyerror!anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_data) |cached| {
            return cached;
        }
        const value = try DigitalCredentialImpl.get_data(instance);
        state.cached_data = value;
        return value;
    }

    pub fn call_willRequestConditionalCreation(instance: *runtime.Instance) anyerror!anyopaque {
        return try DigitalCredentialImpl.call_willRequestConditionalCreation(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!anyopaque {
        return try DigitalCredentialImpl.call_toJSON(instance);
    }

    pub fn call_userAgentAllowsProtocol(instance: *runtime.Instance, protocol: DOMString) anyerror!bool {
        
        return try DigitalCredentialImpl.call_userAgentAllowsProtocol(instance, protocol);
    }

    pub fn call_isConditionalMediationAvailable(instance: *runtime.Instance) anyerror!anyopaque {
        return try DigitalCredentialImpl.call_isConditionalMediationAvailable(instance);
    }

};
