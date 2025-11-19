//! Generated from: turtledove.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ProtectedAudienceUtilitiesImpl = @import("impls").ProtectedAudienceUtilities;
const Uint8Array = @import("interfaces").Uint8Array;
const USVString = @import("interfaces").USVString;

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
        return ProtectedAudienceUtilitiesImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ProtectedAudienceUtilitiesImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_decodeUtf8(instance: *runtime.Instance, bytes: anyopaque) anyerror!runtime.USVString {
        
        return try ProtectedAudienceUtilitiesImpl.call_decodeUtf8(instance, bytes);
    }

    pub fn call_encodeUtf8(instance: *runtime.Instance, input: runtime.USVString) anyerror!anyopaque {
        
        return try ProtectedAudienceUtilitiesImpl.call_encodeUtf8(instance, input);
    }

};
