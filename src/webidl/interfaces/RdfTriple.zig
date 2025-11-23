//! Generated from: json-ld-api.idl
//! Generated at: 2025-11-23T16:59:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RdfTripleImpl = @import("impls").RdfTriple;
const RdfLiteral = @import("interfaces").RdfLiteral;
const USVString = @import("interfaces").USVString;

pub const RdfTriple = struct {
    pub const Meta = struct {
        pub const name = "RdfTriple";
        pub const is_mixin = false;
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
            .{ "subject", "get_subject", null },
            .{ "predicate", "get_predicate", null },
            .{ "_object", "get__object", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
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
            .{ "subject", "get_subject", null },
            .{ "predicate", "get_predicate", null },
            .{ "_object", "get__object", null },
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
            subject: runtime.USVString = undefined,
            predicate: runtime.USVString = undefined,
            _object: union(enum) {
                USVString: runtime.USVString,
                RdfLiteral: RdfLiteral,
            } = undefined,
            _internal: ?*RdfTripleImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get__object = &get__object,
        .get_predicate = &get_predicate,
        .get_subject = &get_subject,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return RdfTripleImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RdfTripleImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try RdfTripleImpl.call_constructor(allocator, ctx);
    }

    pub fn get_subject(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try RdfTripleImpl.get_subject(instance);
    }

    pub fn get_predicate(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try RdfTripleImpl.get_predicate(instance);
    }

    pub fn get__object(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try RdfTripleImpl.get__object(instance);
    }

};
