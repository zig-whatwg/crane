//! Generated from: media-capabilities.idl
//! Generated at: 2025-11-19T20:02:00Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MediaCapabilitiesImpl = @import("impls").MediaCapabilities;
const MediaCapabilitiesEncodingInfo = @import("dictionaries").MediaCapabilitiesEncodingInfo;
const MediaEncodingConfiguration = @import("dictionaries").MediaEncodingConfiguration;
const MediaDecodingConfiguration = @import("dictionaries").MediaDecodingConfiguration;
const MediaCapabilitiesDecodingInfo = @import("dictionaries").MediaCapabilitiesDecodingInfo;

pub const MediaCapabilities = struct {
    pub const Meta = struct {
        pub const name = "MediaCapabilities";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(MediaCapabilities, .{
        .deinit_fn = &deinit_wrapper,

        .call_decodingInfo = &call_decodingInfo,
        .call_encodingInfo = &call_encodingInfo,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return MediaCapabilitiesImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MediaCapabilitiesImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_encodingInfo(instance: *runtime.Instance, configuration: MediaEncodingConfiguration) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        
        return try MediaCapabilitiesImpl.call_encodingInfo(instance, configuration);
    }

    /// Extended attributes: [NewObject]
    pub fn call_decodingInfo(instance: *runtime.Instance, configuration: MediaDecodingConfiguration) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        
        return try MediaCapabilitiesImpl.call_decodingInfo(instance, configuration);
    }

};
