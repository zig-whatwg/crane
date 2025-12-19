//! Generated from: css-parser-api.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CSSParserQualifiedRuleImpl = @import("impls").CSSParserQualifiedRule;
const mixins = @import("mixins");
const CSSParserRule = @import("interfaces").CSSParserRule;
const CSSToken = @import("typedefs").CSSToken;
const CSSParserValue = @import("interfaces").CSSParserValue;
const DOMString = @import("typedefs").DOMString;

pub const CSSParserQualifiedRule = struct {
    pub const Meta = struct {
        pub const name = "CSSParserQualifiedRule";
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
            .{ "prelude", "get_prelude", null },
            .{ "body", "get_body", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "toString", "serialize", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "toString",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "prelude", "get_prelude", null },
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
            prelude: runtime.FrozenArray(CSSParserValue) = undefined,
            body: runtime.FrozenArray(CSSParserRule) = undefined,
            _internal: ?*CSSParserQualifiedRuleImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_body = &get_body,
        .get_prelude = &get_prelude,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSParserQualifiedRuleImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return CSSParserQualifiedRuleImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSParserQualifiedRuleImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, prelude: runtime.JSValue, body: webidl.Opt(?runtime.JSValue)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try CSSParserQualifiedRuleImpl.call_constructor(ctx, prelude, body);
    }

    pub fn get_prelude(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try CSSParserQualifiedRuleImpl.get_prelude(instance);
    }

    pub fn get_body(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try CSSParserQualifiedRuleImpl.get_body(instance);
    }

    pub fn call_stringifier(instance: *runtime.Instance) anyerror!DOMString {
        return try CSSParserQualifiedRuleImpl.call_stringifier(instance);
    }

    /// Stringifier delegate - toString() implementation
    /// Per WebIDL spec: https://webidl.spec.whatwg.org/#es-stringifier
    pub fn serialize(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try CSSParserQualifiedRuleImpl.serialize(instance);
    }

};
