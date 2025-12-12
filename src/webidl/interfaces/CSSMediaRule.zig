//! Generated from: css-conditional.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CSSMediaRuleImpl = @import("impls").CSSMediaRule;
const mixins = @import("mixins");
const CSSConditionRule = @import("interfaces").CSSConditionRule;
const CSSStyleSheet = @import("interfaces").CSSStyleSheet;
const CSSOMString = @import("typedefs").CSSOMString;
const CSSRule = @import("interfaces").CSSRule;
const CSSRuleList = @import("interfaces").CSSRuleList;
const DOMString = @import("typedefs").DOMString;
const MediaList = @import("interfaces").MediaList;

pub const CSSMediaRule = struct {
    pub const Meta = struct {
        pub const name = "CSSMediaRule";
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
            .{ "media", "get_media", null },
            .{ "matches", "get_matches", null },
            .{ "media", "get_media", null },
            .{ "cssRules", "get_cssRules", null },
        };
        
        /// [PutForwards] attributes: setting the attribute forwards to a property on the value
        /// Format: { "attrName", "forwardedProperty" }
        pub const put_forwards_attributes = .{
            .{ "media", "mediaText" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "insertRule", "call_insertRule", 2 },
            .{ "deleteRule", "call_deleteRule", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "insertRule",
            "deleteRule",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "media", "get_media", null },
            .{ "matches", "get_matches", null },
            .{ "media", "get_media", null },
            .{ "cssRules", "get_cssRules", null },
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
            media: *runtime.Instance = undefined,
            matches: bool = undefined,
            cssRules: *runtime.Instance = undefined,
            cached_media: ?*runtime.Instance = null,
            _internal: ?*CSSMediaRuleImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_cssRules = &get_cssRules,
        .get_matches = &get_matches,
        .get_media = &get_media,

        .call_deleteRule = &call_deleteRule,
        .call_insertRule = &call_insertRule,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSMediaRuleImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return CSSMediaRuleImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSMediaRuleImpl.deinit(instance);
    }

    /// Extended attributes: [SameObject], [PutForwards=mediaText]
    pub fn get_media(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_media) |cached| {
            return cached;
        }
        const value = try CSSMediaRuleImpl.get_media(instance);
        state.own.cached_media = value;
        return value;
    }

    /// Extended attributes: [SameObject], [PutForwards=mediaText]
    pub fn set_media(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [PutForwards] - Get target object and set the forwarded property
        // Per WebIDL spec: setting 'media' forwards to 'mediaText' on the attribute's value
        const target = try get_media(instance);
        
        // Use JavaScript [[Set]] semantics to set the forwarded property
        // This respects prototype chain and user-defined setters
        try runtime.setPropertyOnInstance(target, "mediaText", value);
    }

    pub fn get_matches(instance: *runtime.Instance) anyerror!bool {
        return try CSSMediaRuleImpl.get_matches(instance);
    }

    pub fn get_cssRules(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try CSSMediaRuleImpl.get_cssRules(instance);
    }

    pub fn call_insertRule(instance: *runtime.Instance, rule: DOMString, index: u32) anyerror!u32 {
        
        return try CSSMediaRuleImpl.call_insertRule(instance, rule, index);
    }

    pub fn call_deleteRule(instance: *runtime.Instance, index: u32) anyerror!void {
        
        return try CSSMediaRuleImpl.call_deleteRule(instance, index);
    }

};
