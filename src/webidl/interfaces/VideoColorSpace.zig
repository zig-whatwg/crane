//! Generated from: webcodecs.idl
//! Generated at: 2025-11-28T03:24:38Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const VideoColorSpaceImpl = @import("impls").VideoColorSpace;
const VideoTransferCharacteristics = @import("enums").VideoTransferCharacteristics;
const VideoColorSpaceInit = @import("dictionaries").VideoColorSpaceInit;
const VideoMatrixCoefficients = @import("enums").VideoMatrixCoefficients;
const VideoColorPrimaries = @import("enums").VideoColorPrimaries;

pub const VideoColorSpace = struct {
    pub const Meta = struct {
        pub const name = "VideoColorSpace";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "primaries", "get_primaries", null },
            .{ "transfer", "get_transfer", null },
            .{ "matrix", "get_matrix", null },
            .{ "fullRange", "get_fullRange", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "toJSON", "call_toJSON", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "toJSON",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "primaries", "get_primaries", null },
            .{ "transfer", "get_transfer", null },
            .{ "matrix", "get_matrix", null },
            .{ "fullRange", "get_fullRange", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            primaries: ?VideoColorPrimaries = null,
            transfer: ?VideoTransferCharacteristics = null,
            matrix: ?VideoMatrixCoefficients = null,
            fullRange: ?bool = null,
            _internal: ?*VideoColorSpaceImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_fullRange = &get_fullRange,
        .get_matrix = &get_matrix,
        .get_primaries = &get_primaries,
        .get_transfer = &get_transfer,

        .call_toJSON = &call_toJSON,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return VideoColorSpaceImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        VideoColorSpaceImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, init_data: VideoColorSpaceInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try VideoColorSpaceImpl.call_constructor(allocator, ctx, init_data);
    }

    pub fn get_primaries(instance: *runtime.Instance) anyerror!?VideoColorPrimaries {
        return try VideoColorSpaceImpl.get_primaries(instance);
    }

    pub fn get_transfer(instance: *runtime.Instance) anyerror!?VideoTransferCharacteristics {
        return try VideoColorSpaceImpl.get_transfer(instance);
    }

    pub fn get_matrix(instance: *runtime.Instance) anyerror!?VideoMatrixCoefficients {
        return try VideoColorSpaceImpl.get_matrix(instance);
    }

    pub fn get_fullRange(instance: *runtime.Instance) anyerror!?bool {
        return try VideoColorSpaceImpl.get_fullRange(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!VideoColorSpaceInit {
        return try VideoColorSpaceImpl.call_toJSON(instance);
    }

};
