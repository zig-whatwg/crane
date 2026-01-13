//! Generated from: css-conditional-5.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CSSContainerRuleImpl = @import("impls").CSSContainerRule;
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

pub const CSSContainerRule = struct {
    pub const Meta = struct {
        pub const name = "CSSContainerRule";
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
            .{ "containerName", "get_containerName", null },
            .{ "containerQuery", "get_containerQuery", null },
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
            .{ "containerName", "get_containerName", null },
            .{ "containerQuery", "get_containerQuery", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
        };
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            containerName: typedefs.CSSOMString = undefined,
            containerQuery: typedefs.CSSOMString = undefined,
            _internal: ?*CSSContainerRuleImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_containerName = &get_containerName,
        .get_containerQuery = &get_containerQuery,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSContainerRuleImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return CSSContainerRuleImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSContainerRuleImpl.deinit(instance);
    }

    pub fn get_containerName(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSContainerRuleImpl.get_containerName(instance);
    }

    pub fn get_containerQuery(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSContainerRuleImpl.get_containerQuery(instance);
    }

};
