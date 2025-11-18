//! Generated from: turtledove.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ProtectedAudienceUtilitiesImpl = @import("../impls/ProtectedAudienceUtilities.zig");

pub const ProtectedAudienceUtilities = struct {
    pub const Meta = struct {
        pub const name = "ProtectedAudienceUtilities";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "InterestGroupScriptRunnerGlobalScope" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .InterestGroupScriptRunnerGlobalScope = true };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ProtectedAudienceUtilities, .{
        .deinit_fn = &deinit_wrapper,

        .call_decodeUtf8 = &call_decodeUtf8,
        .call_encodeUtf8 = &call_encodeUtf8,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        ProtectedAudienceUtilitiesImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        ProtectedAudienceUtilitiesImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_decodeUtf8(instance: *runtime.Instance, bytes: anyopaque) runtime.USVString {
        const state = instance.getState(State);
        
        return ProtectedAudienceUtilitiesImpl.call_decodeUtf8(state, bytes);
    }

    pub fn call_encodeUtf8(instance: *runtime.Instance, input: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        
        return ProtectedAudienceUtilitiesImpl.call_encodeUtf8(state, input);
    }

};
