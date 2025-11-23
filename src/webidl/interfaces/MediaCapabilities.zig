//! Generated from: media-capabilities.idl
//! Generated at: 2025-11-23T14:26:29Z
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
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "decodingInfo", "call_decodingInfo", 1 },
            .{ "encodingInfo", "call_encodingInfo", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "decodingInfo",
            "encodingInfo",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {},
    );

    const delegates = .{

        .call_decodingInfo = &call_decodingInfo,
        .call_encodingInfo = &call_encodingInfo,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return MediaCapabilitiesImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MediaCapabilitiesImpl.deinit(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_encodingInfo(instance: *runtime.Instance, configuration: MediaEncodingConfiguration) anyerror!*const anyopaque {
        // [NewObject] - Caller owns the returned object
        
        return try MediaCapabilitiesImpl.call_encodingInfo(instance, configuration);
    }

    /// Extended attributes: [NewObject]
    pub fn call_decodingInfo(instance: *runtime.Instance, configuration: MediaDecodingConfiguration) anyerror!*const anyopaque {
        // [NewObject] - Caller owns the returned object
        
        return try MediaCapabilitiesImpl.call_decodingInfo(instance, configuration);
    }

};
