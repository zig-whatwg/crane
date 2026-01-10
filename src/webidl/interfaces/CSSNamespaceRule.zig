//! Generated from: cssom.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CSSNamespaceRuleImpl = @import("impls").CSSNamespaceRule;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const CSSRule = @import("CSSRule.zig").CSSRule;
const CSSStyleSheet = @import("CSSStyleSheet.zig").CSSStyleSheet;
const CSSOMString = @import("typedefs").CSSOMString;
const DOMString = @import("typedefs").DOMString;

pub const CSSNamespaceRule = struct {
    pub const Meta = struct {
        pub const name = "CSSNamespaceRule";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = CSSRule.State;
        pub const ParentInterface = CSSRule;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "namespaceURI", "get_namespaceURI", null },
            .{ "prefix", "get_prefix", null },
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
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
            .{ "namespaceURI", "get_namespaceURI", null },
            .{ "prefix", "get_prefix", null },
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            namespaceURI: typedefs.CSSOMString = undefined,
            prefix: typedefs.CSSOMString = undefined,
            _internal: ?*CSSNamespaceRuleImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_namespaceURI = &get_namespaceURI,
        .get_prefix = &get_prefix,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSNamespaceRuleImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return CSSNamespaceRuleImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSNamespaceRuleImpl.deinit(instance);
    }

    pub fn get_namespaceURI(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSNamespaceRuleImpl.get_namespaceURI(instance);
    }

    pub fn get_prefix(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSNamespaceRuleImpl.get_prefix(instance);
    }

};
