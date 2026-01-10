//! Generated from: css-conditional.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CSSSupportsRuleImpl = @import("impls").CSSSupportsRule;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const CSSConditionRule = @import("CSSConditionRule.zig").CSSConditionRule;
const CSSStyleSheet = @import("CSSStyleSheet.zig").CSSStyleSheet;
const CSSOMString = @import("typedefs").CSSOMString;
const CSSRule = @import("CSSRule.zig").CSSRule;
const DOMString = @import("typedefs").DOMString;
const CSSRuleList = @import("CSSRuleList.zig").CSSRuleList;

pub const CSSSupportsRule = struct {
    pub const Meta = struct {
        pub const name = "CSSSupportsRule";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = CSSConditionRule.State;
        pub const ParentInterface = CSSConditionRule;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "matches", "get_matches", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "insertRule",
            "deleteRule",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "matches", "get_matches", null },
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
            matches: bool = undefined,
            _internal: ?*CSSSupportsRuleImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_matches = &get_matches,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSSupportsRuleImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return CSSSupportsRuleImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSSupportsRuleImpl.deinit(instance);
    }

    pub fn get_matches(instance: *runtime.Instance) anyerror!bool {
        return try CSSSupportsRuleImpl.get_matches(instance);
    }

};
