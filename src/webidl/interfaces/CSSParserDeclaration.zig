//! Generated from: css-parser-api.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CSSParserDeclarationImpl = @import("impls").CSSParserDeclaration;
const mixins = @import("mixins");
const CSSParserRule = @import("interfaces").CSSParserRule;
const CSSParserValue = @import("interfaces").CSSParserValue;
const DOMString = @import("typedefs").DOMString;

pub const CSSParserDeclaration = struct {
    pub const Meta = struct {
        pub const name = "CSSParserDeclaration";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = CSSParserRule.State;
        pub const ParentInterface = CSSParserRule;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "name", "get_name", null },
            .{ "body", "get_body", null },
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
            .{ "name", "get_name", null },
            .{ "body", "get_body", null },
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
            name: runtime.DOMString = undefined,
            body: runtime.FrozenArray(CSSParserValue) = undefined,
            _internal: ?*CSSParserDeclarationImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_body = &get_body,
        .get_name = &get_name,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSParserDeclarationImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSParserDeclarationImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, name: DOMString, body: webidl.Opt(*const anyopaque)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try CSSParserDeclarationImpl.call_constructor(allocator, ctx, name, body);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try CSSParserDeclarationImpl.get_name(instance);
    }

    pub fn get_body(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try CSSParserDeclarationImpl.get_body(instance);
    }

};
