//! Generated from: json-ld-api.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const RdfLiteralImpl = @import("impls").RdfLiteral;
const mixins = @import("mixins");
const USVString = @import("interfaces").USVString;

pub const RdfLiteral = struct {
    pub const Meta = struct {
        pub const name = "RdfLiteral";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "JsonLd" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .JsonLd = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "value", "get_value", null },
            .{ "datatype", "get_datatype", null },
            .{ "language", "get_language", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "value", "get_value", null },
            .{ "datatype", "get_datatype", null },
            .{ "language", "get_language", null },
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
            value: runtime.USVString = undefined,
            datatype: runtime.USVString = undefined,
            language: ?runtime.USVString = null,
            _internal: ?*RdfLiteralImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_datatype = &get_datatype,
        .get_language = &get_language,
        .get_value = &get_value,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return RdfLiteralImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RdfLiteralImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try RdfLiteralImpl.call_constructor(allocator, ctx);
    }

    pub fn get_value(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try RdfLiteralImpl.get_value(instance);
    }

    pub fn get_datatype(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try RdfLiteralImpl.get_datatype(instance);
    }

    pub fn get_language(instance: *runtime.Instance) anyerror!?runtime.USVString {
        return try RdfLiteralImpl.get_language(instance);
    }

};
