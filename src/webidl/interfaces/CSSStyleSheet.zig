//! Generated from: cssom.idl
//! Generated at: 2025-11-19T20:02:00Z
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
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *StyleSheet;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            ownerRule: ?CSSRule = null,
            cssRules: CSSRuleList = undefined,
            rules: CSSRuleList = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CSSStyleSheet, .{
        .deinit_fn = &deinit_wrapper,

        .get_cssRules = &get_cssRules,
        .get_disabled = &get_disabled,
        .get_href = &get_href,
        .get_media = &get_media,
        .get_ownerNode = &get_ownerNode,
        .get_ownerRule = &get_ownerRule,
        .get_parentStyleSheet = &get_parentStyleSheet,
        .get_rules = &get_rules,
        .get_title = &get_title,
        .get_type = &get_type,

        .set_disabled = &set_disabled,

        .call_addRule = &call_addRule,
        .call_deleteRule = &call_deleteRule,
        .call_insertRule = &call_insertRule,
        .call_removeRule = &call_removeRule,
        .call_replace = &call_replace,
        .call_replaceSync = &call_replaceSync,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return CSSStyleSheetImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSStyleSheetImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, options: CSSStyleSheetInit) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try CSSStyleSheetImpl.constructor(instance, options);
        
        return instance;
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSStyleSheetImpl.get_type(instance);
    }

    pub fn get_href(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try CSSStyleSheetImpl.get_href(instance);
    }

    pub fn get_ownerNode(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSStyleSheetImpl.get_ownerNode(instance);
    }

    pub fn get_parentStyleSheet(instance: *runtime.Instance) anyerror!CSSStyleSheet {
        return try CSSStyleSheetImpl.get_parentStyleSheet(instance);
    }

    pub fn get_title(instance: *runtime.Instance) anyerror!DOMString {
        return try CSSStyleSheetImpl.get_title(instance);
    }

    /// Extended attributes: [SameObject], [PutForwards=mediaText]
    pub fn get_media(instance: *runtime.Instance) anyerror!MediaList {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_media) |cached| {
            return cached;
        }
        const value = try CSSStyleSheetImpl.get_media(instance);
        state.cached_media = value;
        return value;
    }

    pub fn get_disabled(instance: *runtime.Instance) anyerror!bool {
        return try CSSStyleSheetImpl.get_disabled(instance);
    }

    pub fn set_disabled(instance: *runtime.Instance, value: bool) anyerror!void {
        try CSSStyleSheetImpl.set_disabled(instance, value);
    }

    pub fn get_ownerRule(instance: *runtime.Instance) anyerror!CSSRule {
        return try CSSStyleSheetImpl.get_ownerRule(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_cssRules(instance: *runtime.Instance) anyerror!CSSRuleList {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_cssRules) |cached| {
            return cached;
        }
        const value = try CSSStyleSheetImpl.get_cssRules(instance);
        state.cached_cssRules = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_rules(instance: *runtime.Instance) anyerror!CSSRuleList {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_rules) |cached| {
            return cached;
        }
        const value = try CSSStyleSheetImpl.get_rules(instance);
        state.cached_rules = value;
        return value;
    }

    pub fn call_deleteRule(instance: *runtime.Instance, index: u32) anyerror!void {
        
        return try CSSStyleSheetImpl.call_deleteRule(instance, index);
    }

    pub fn call_replaceSync(instance: *runtime.Instance, text: runtime.USVString) anyerror!void {
        
        return try CSSStyleSheetImpl.call_replaceSync(instance, text);
    }

    pub fn call_replace(instance: *runtime.Instance, text: runtime.USVString) anyerror!anyopaque {
        
        return try CSSStyleSheetImpl.call_replace(instance, text);
    }

    pub fn call_insertRule(instance: *runtime.Instance, rule: anyopaque, index: u32) anyerror!u32 {
        
        return try CSSStyleSheetImpl.call_insertRule(instance, rule, index);
    }

    pub fn call_addRule(instance: *runtime.Instance, selector: DOMString, style: DOMString, index: u32) anyerror!i32 {
        
        return try CSSStyleSheetImpl.call_addRule(instance, selector, style, index);
    }

    pub fn call_removeRule(instance: *runtime.Instance, index: u32) anyerror!void {
        
        return try CSSStyleSheetImpl.call_removeRule(instance, index);
    }

};
