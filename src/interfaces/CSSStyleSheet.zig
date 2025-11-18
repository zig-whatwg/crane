//! Generated from: cssom.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSStyleSheetImpl = @import("../impls/CSSStyleSheet.zig");
const StyleSheet = @import("StyleSheet.zig");

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
            ownerRule: CSSRule = undefined,
            cssRules: CSSRuleList = undefined,
            rules: CSSRuleList = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CSSStyleSheet, .{
        .deinit_fn = &deinit_wrapper,

        .get_cssRules = &get_cssRules,
        .get_cssRules = &get_cssRules,
        .get_disabled = &get_disabled,
        .get_disabled = &get_disabled,
        .get_href = &get_href,
        .get_href = &get_href,
        .get_media = &get_media,
        .get_media = &get_media,
        .get_ownerNode = &get_ownerNode,
        .get_ownerNode = &get_ownerNode,
        .get_ownerRule = &get_ownerRule,
        .get_ownerRule = &get_ownerRule,
        .get_parentStyleSheet = &get_parentStyleSheet,
        .get_parentStyleSheet = &get_parentStyleSheet,
        .get_rules = &get_rules,
        .get_title = &get_title,
        .get_title = &get_title,
        .get_type = &get_type,
        .get_type = &get_type,

        .set_disabled = &set_disabled,
        .set_disabled = &set_disabled,

        .call_addRule = &call_addRule,
        .call_deleteRule = &call_deleteRule,
        .call_deleteRule = &call_deleteRule,
        .call_insertRule = &call_insertRule,
        .call_insertRule = &call_insertRule,
        .call_removeRule = &call_removeRule,
        .call_replace = &call_replace,
        .call_replaceSync = &call_replaceSync,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        CSSStyleSheetImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CSSStyleSheetImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, options: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try CSSStyleSheetImpl.constructor(state, options);
        
        return instance;
    }

    pub fn get_type(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSStyleSheetImpl.get_type(state);
    }

    pub fn get_href(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSStyleSheetImpl.get_href(state);
    }

    pub fn get_ownerNode(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSStyleSheetImpl.get_ownerNode(state);
    }

    pub fn get_parentStyleSheet(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSStyleSheetImpl.get_parentStyleSheet(state);
    }

    pub fn get_title(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSStyleSheetImpl.get_title(state);
    }

    /// Extended attributes: [SameObject], [PutForwards=mediaText]
    pub fn get_media(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_media) |cached| {
            return cached;
        }
        const value = CSSStyleSheetImpl.get_media(state);
        state.cached_media = value;
        return value;
    }

    pub fn get_disabled(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return CSSStyleSheetImpl.get_disabled(state);
    }

    pub fn set_disabled(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        CSSStyleSheetImpl.set_disabled(state, value);
    }

    pub fn get_type(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return CSSStyleSheetImpl.get_type(state);
    }

    pub fn get_disabled(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return CSSStyleSheetImpl.get_disabled(state);
    }

    pub fn set_disabled(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        CSSStyleSheetImpl.set_disabled(state, value);
    }

    pub fn get_ownerNode(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSStyleSheetImpl.get_ownerNode(state);
    }

    pub fn get_parentStyleSheet(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSStyleSheetImpl.get_parentStyleSheet(state);
    }

    pub fn get_href(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return CSSStyleSheetImpl.get_href(state);
    }

    pub fn get_title(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return CSSStyleSheetImpl.get_title(state);
    }

    pub fn get_media(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSStyleSheetImpl.get_media(state);
    }

    pub fn get_ownerRule(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSStyleSheetImpl.get_ownerRule(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_cssRules(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_cssRules) |cached| {
            return cached;
        }
        const value = CSSStyleSheetImpl.get_cssRules(state);
        state.cached_cssRules = value;
        return value;
    }

    pub fn get_ownerRule(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSStyleSheetImpl.get_ownerRule(state);
    }

    pub fn get_cssRules(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSStyleSheetImpl.get_cssRules(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_rules(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_rules) |cached| {
            return cached;
        }
        const value = CSSStyleSheetImpl.get_rules(state);
        state.cached_rules = value;
        return value;
    }

    /// Arguments for deleteRule (WebIDL overloading)
    pub const DeleteRuleArgs = union(enum) {
        /// deleteRule(index)
        long: u32,
        /// deleteRule(index)
        long: u32,
    };

    pub fn call_deleteRule(instance: *runtime.Instance, args: DeleteRuleArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .long => |arg| return CSSStyleSheetImpl.long(state, arg),
            .long => |arg| return CSSStyleSheetImpl.long(state, arg),
        }
    }

    pub fn call_replaceSync(instance: *runtime.Instance, text: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        
        return CSSStyleSheetImpl.call_replaceSync(state, text);
    }

    pub fn call_replace(instance: *runtime.Instance, text: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        
        return CSSStyleSheetImpl.call_replace(state, text);
    }

    /// Arguments for insertRule (WebIDL overloading)
    pub const InsertRuleArgs = union(enum) {
        /// insertRule(rule, index)
        CSSOMString_long: struct {
            rule: anyopaque,
            index: u32,
        },
        /// insertRule(rule, index)
        string_long: struct {
            rule: runtime.DOMString,
            index: u32,
        },
    };

    pub fn call_insertRule(instance: *runtime.Instance, args: InsertRuleArgs) u32 {
        const state = instance.getState(State);
        switch (args) {
            .CSSOMString_long => |a| return CSSStyleSheetImpl.CSSOMString_long(state, a.rule, a.index),
            .string_long => |a| return CSSStyleSheetImpl.string_long(state, a.rule, a.index),
        }
    }

    pub fn call_addRule(instance: *runtime.Instance, selector: runtime.DOMString, style: runtime.DOMString, index: u32) i32 {
        const state = instance.getState(State);
        
        return CSSStyleSheetImpl.call_addRule(state, selector, style, index);
    }

    pub fn call_removeRule(instance: *runtime.Instance, index: u32) anyopaque {
        const state = instance.getState(State);
        
        return CSSStyleSheetImpl.call_removeRule(state, index);
    }

};
