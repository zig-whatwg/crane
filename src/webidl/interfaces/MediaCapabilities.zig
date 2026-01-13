//! Generated from: media-capabilities.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const MediaCapabilitiesImpl = @import("impls").MediaCapabilities;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const MediaCapabilitiesEncodingInfo = @import("dictionaries").MediaCapabilitiesEncodingInfo;
const MediaEncodingConfiguration = @import("dictionaries").MediaEncodingConfiguration;
const MediaDecodingConfiguration = @import("dictionaries").MediaDecodingConfiguration;
const MediaCapabilitiesDecodingInfo = @import("dictionaries").MediaCapabilitiesDecodingInfo;

pub const MediaCapabilities = struct {
    pub const Meta = struct {
        pub const name = "MediaCapabilities";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
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
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
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
        struct {
            _internal: ?*MediaCapabilitiesImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_decodingInfo = &call_decodingInfo,
        .call_encodingInfo = &call_encodingInfo,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return MediaCapabilitiesImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return MediaCapabilitiesImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MediaCapabilitiesImpl.deinit(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_encodingInfo(instance: *runtime.Instance, configuration: MediaEncodingConfiguration) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object
        
        return try MediaCapabilitiesImpl.call_encodingInfo(instance, configuration);
    }

    /// Extended attributes: [NewObject]
    pub fn call_decodingInfo(instance: *runtime.Instance, configuration: MediaDecodingConfiguration) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object
        
        return try MediaCapabilitiesImpl.call_decodingInfo(instance, configuration);
    }

};
