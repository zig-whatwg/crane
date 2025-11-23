//! Generated from: cssom.idl
//! Generated at: 2025-11-23T14:26:29Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSStyleSheetImpl = @import("impls").CSSStyleSheet;
const StyleSheet = @import("interfaces").StyleSheet;
const CSSStyleSheetInit = @import("dictionaries").CSSStyleSheetInit;
const CSSRule = @import("interfaces").CSSRule;
const CSSOMString = @import("interfaces").CSSOMString;
const Node = @import("interfaces").Node;
const USVString = @import("interfaces").USVString;
const MediaList = @import("interfaces").MediaList;
const Element = @import("interfaces").Element;
const CSSRuleList = @import("interfaces").CSSRuleList;
const ProcessingInstruction = @import("interfaces").ProcessingInstruction;
const DOMString = @import("typedefs").DOMString;

pub const CSSStyleSheet = struct {
    pub const Meta = struct {
        pub const name = "CSSStyleSheet";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *StyleSheet;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "ownerRule", "get_ownerRule", null },
            .{ "cssRules", "get_cssRules", null },
            .{ "ownerRule", "get_ownerRule", null },
            .{ "cssRules", "get_cssRules", null },
            .{ "rules", "get_rules", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "insertRule", "call_insertRule", 1 },
            .{ "deleteRule", "call_deleteRule", 1 },
            .{ "replace", "call_replace", 1 },
            .{ "replaceSync", "call_replaceSync", 1 },
            .{ "insertRule", "call_insertRule", 2 },
            .{ "deleteRule", "call_deleteRule", 1 },
            .{ "addRule", "call_addRule", 0 },
            .{ "removeRule", "call_removeRule", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "insertRule",
            "deleteRule",
            "replace",
            "replaceSync",
            "insertRule",
            "deleteRule",
            "addRule",
            "removeRule",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "ownerRule", "get_ownerRule", null },
            .{ "cssRules", "get_cssRules", null },
            .{ "ownerRule", "get_ownerRule", null },
            .{ "cssRules", "get_cssRules", null },
            .{ "rules", "get_rules", null },
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
            ownerRule: ?CSSRule = null,
            cssRules: CSSRuleList = undefined,
            rules: CSSRuleList = undefined,
            cached_cssRules: ?CSSRuleList = null,
            cached_rules: ?CSSRuleList = null,
            _internal: ?*CSSStyleSheetImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_cssRules = &get_cssRules,
        .get_ownerRule = &get_ownerRule,
        .get_rules = &get_rules,

        .call_addRule = &call_addRule,
        .call_deleteRule = &call_deleteRule,
        .call_insertRule = &call_insertRule,
        .call_removeRule = &call_removeRule,
        .call_replace = &call_replace,
        .call_replaceSync = &call_replaceSync,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSStyleSheetImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSStyleSheetImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, options: CSSStyleSheetInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try CSSStyleSheetImpl.call_constructor(allocator, ctx, options);
    }

    pub fn get_ownerRule(instance: *runtime.Instance) anyerror!CSSRule {
        return try CSSStyleSheetImpl.get_ownerRule(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_cssRules(instance: *runtime.Instance) anyerror!CSSRuleList {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_cssRules) |cached| {
            return cached;
        }
        const value = try CSSStyleSheetImpl.get_cssRules(instance);
        state.own.cached_cssRules = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_rules(instance: *runtime.Instance) anyerror!CSSRuleList {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_rules) |cached| {
            return cached;
        }
        const value = try CSSStyleSheetImpl.get_rules(instance);
        state.own.cached_rules = value;
        return value;
    }

    pub fn call_deleteRule(instance: *runtime.Instance, index: u32) anyerror!void {
        
        return try CSSStyleSheetImpl.call_deleteRule(instance, index);
    }

    pub fn call_replaceSync(instance: *runtime.Instance, text: runtime.USVString) anyerror!void {
        
        return try CSSStyleSheetImpl.call_replaceSync(instance, text);
    }

    pub fn call_replace(instance: *runtime.Instance, text: runtime.USVString) anyerror!*const anyopaque {
        
        return try CSSStyleSheetImpl.call_replace(instance, text);
    }

    pub fn call_insertRule(instance: *runtime.Instance, rule: *const anyopaque, index: u32) anyerror!u32 {
        
        return try CSSStyleSheetImpl.call_insertRule(instance, rule, index);
    }

    pub fn call_addRule(instance: *runtime.Instance, selector: DOMString, style: DOMString, index: u32) anyerror!i32 {
        
        return try CSSStyleSheetImpl.call_addRule(instance, selector, style, index);
    }

    pub fn call_removeRule(instance: *runtime.Instance, index: u32) anyerror!void {
        
        return try CSSStyleSheetImpl.call_removeRule(instance, index);
    }

};
