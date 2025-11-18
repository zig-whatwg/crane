//! Generated from: cssom.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSImportRuleImpl = @import("../impls/CSSImportRule.zig");
const CSSRule = @import("CSSRule.zig");

pub const CSSImportRule = struct {
    pub const Meta = struct {
        pub const name = "CSSImportRule";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *CSSRule;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            href: runtime.USVString = undefined,
            media: MediaList = undefined,
            styleSheet: ?CSSStyleSheet = null,
            layerName: ?CSSOMString = null,
            supportsText: ?CSSOMString = null,
            href: runtime.DOMString = undefined,
            media: stylesheets::MediaList = undefined,
            styleSheet: CSSStyleSheet = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CSSImportRule, .{
        .deinit_fn = &deinit_wrapper,

        .get_CHARSET_RULE = &CSSRule.get_CHARSET_RULE,
        .get_CHARSET_RULE = &CSSRule.get_CHARSET_RULE,
        .get_COUNTER_STYLE_RULE = &CSSRule.get_COUNTER_STYLE_RULE,
        .get_FONT_FACE_RULE = &CSSRule.get_FONT_FACE_RULE,
        .get_FONT_FACE_RULE = &CSSRule.get_FONT_FACE_RULE,
        .get_FONT_FEATURE_VALUES_RULE = &CSSRule.get_FONT_FEATURE_VALUES_RULE,
        .get_IMPORT_RULE = &CSSRule.get_IMPORT_RULE,
        .get_IMPORT_RULE = &CSSRule.get_IMPORT_RULE,
        .get_KEYFRAMES_RULE = &CSSRule.get_KEYFRAMES_RULE,
        .get_KEYFRAME_RULE = &CSSRule.get_KEYFRAME_RULE,
        .get_MARGIN_RULE = &CSSRule.get_MARGIN_RULE,
        .get_MEDIA_RULE = &CSSRule.get_MEDIA_RULE,
        .get_MEDIA_RULE = &CSSRule.get_MEDIA_RULE,
        .get_NAMESPACE_RULE = &CSSRule.get_NAMESPACE_RULE,
        .get_PAGE_RULE = &CSSRule.get_PAGE_RULE,
        .get_PAGE_RULE = &CSSRule.get_PAGE_RULE,
        .get_STYLE_RULE = &CSSRule.get_STYLE_RULE,
        .get_STYLE_RULE = &CSSRule.get_STYLE_RULE,
        .get_SUPPORTS_RULE = &CSSRule.get_SUPPORTS_RULE,
        .get_UNKNOWN_RULE = &CSSRule.get_UNKNOWN_RULE,
        .get_cssText = &get_cssText,
        .get_cssText = &get_cssText,
        .get_href = &get_href,
        .get_href = &get_href,
        .get_layerName = &get_layerName,
        .get_media = &get_media,
        .get_media = &get_media,
        .get_parentRule = &get_parentRule,
        .get_parentRule = &get_parentRule,
        .get_parentStyleSheet = &get_parentStyleSheet,
        .get_parentStyleSheet = &get_parentStyleSheet,
        .get_styleSheet = &get_styleSheet,
        .get_styleSheet = &get_styleSheet,
        .get_supportsText = &get_supportsText,
        .get_type = &get_type,
        .get_type = &get_type,

        .set_cssText = &set_cssText,
        .set_cssText = &set_cssText,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        CSSImportRuleImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CSSImportRuleImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_cssText(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSImportRuleImpl.get_cssText(state);
    }

    pub fn set_cssText(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSImportRuleImpl.set_cssText(state, value);
    }

    pub fn get_parentRule(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSImportRuleImpl.get_parentRule(state);
    }

    pub fn get_parentStyleSheet(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSImportRuleImpl.get_parentStyleSheet(state);
    }

    pub fn get_type(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return CSSImportRuleImpl.get_type(state);
    }

    pub fn get_type(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return CSSImportRuleImpl.get_type(state);
    }

    pub fn get_cssText(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return CSSImportRuleImpl.get_cssText(state);
    }

    pub fn set_cssText(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        CSSImportRuleImpl.set_cssText(state, value);
    }

    pub fn get_parentStyleSheet(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSImportRuleImpl.get_parentStyleSheet(state);
    }

    pub fn get_parentRule(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSImportRuleImpl.get_parentRule(state);
    }

    pub fn get_href(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return CSSImportRuleImpl.get_href(state);
    }

    /// Extended attributes: [SameObject], [PutForwards=mediaText]
    pub fn get_media(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_media) |cached| {
            return cached;
        }
        const value = CSSImportRuleImpl.get_media(state);
        state.cached_media = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_styleSheet(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_styleSheet) |cached| {
            return cached;
        }
        const value = CSSImportRuleImpl.get_styleSheet(state);
        state.cached_styleSheet = value;
        return value;
    }

    pub fn get_layerName(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSImportRuleImpl.get_layerName(state);
    }

    pub fn get_supportsText(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSImportRuleImpl.get_supportsText(state);
    }

    pub fn get_href(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return CSSImportRuleImpl.get_href(state);
    }

    pub fn get_media(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSImportRuleImpl.get_media(state);
    }

    pub fn get_styleSheet(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSImportRuleImpl.get_styleSheet(state);
    }

};
