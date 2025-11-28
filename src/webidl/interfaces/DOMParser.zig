//! Generated from: html.idl
//! Generated at: 2025-11-28T18:57:57Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const DOMParserImpl = @import("impls").DOMParser;
const mixins = @import("mixins");
const Document = @import("interfaces").Document;
const TrustedHTML = @import("interfaces").TrustedHTML;
const DOMString = @import("typedefs").DOMString;
const DOMParserSupportedType = @import("enums").DOMParserSupportedType;

pub const DOMParser = struct {
    pub const Meta = struct {
        pub const name = "DOMParser";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "parseFromString", "call_parseFromString", 2 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "parseFromString",
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
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*DOMParserImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_parseFromString = &call_parseFromString,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return DOMParserImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DOMParserImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try DOMParserImpl.call_constructor(allocator, ctx);
    }

    /// Extended attributes: [NewObject]
    pub fn call_parseFromString(instance: *runtime.Instance, string: DOMString, @"type": DOMParserSupportedType) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try DOMParserImpl.call_parseFromString(instance, string, @"type");
    }

};
