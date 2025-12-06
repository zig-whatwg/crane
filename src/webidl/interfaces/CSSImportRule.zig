//! Generated from: cssom.idl
//! Generated at: 2025-12-05T20:30:45Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CSSImportRuleImpl = @import("impls").CSSImportRule;
const mixins = @import("mixins");
const CSSRule = @import("interfaces").CSSRule;
const CSSStyleSheet = @import("interfaces").CSSStyleSheet;
const CSSOMString = @import("typedefs").CSSOMString;
const USVString = @import("interfaces").USVString;
const DOMString = @import("typedefs").DOMString;
const MediaList = @import("interfaces").MediaList;

pub const CSSImportRule = struct {
    pub const Meta = struct {
        pub const name = "CSSImportRule";
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
            .{ "href", "get_href", null },
            .{ "media", "get_media", null },
            .{ "styleSheet", "get_styleSheet", null },
            .{ "layerName", "get_layerName", null },
            .{ "supportsText", "get_supportsText", null },
            .{ "href", "get_href", null },
            .{ "media", "get_media", null },
            .{ "styleSheet", "get_styleSheet", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "href", "get_href", null },
            .{ "media", "get_media", null },
            .{ "styleSheet", "get_styleSheet", null },
            .{ "layerName", "get_layerName", null },
            .{ "supportsText", "get_supportsText", null },
            .{ "href", "get_href", null },
            .{ "media", "get_media", null },
            .{ "styleSheet", "get_styleSheet", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            href: runtime.USVString = undefined,
            media: *runtime.Instance = undefined,
            styleSheet: ?*runtime.Instance = null,
            layerName: ?CSSOMString = null,
            supportsText: ?CSSOMString = null,
            cached_media: ?*runtime.Instance = null,
            cached_styleSheet: ?*runtime.Instance = null,
            _internal: ?*CSSImportRuleImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_href = &get_href,
        .get_layerName = &get_layerName,
        .get_media = &get_media,
        .get_styleSheet = &get_styleSheet,
        .get_supportsText = &get_supportsText,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSImportRuleImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSImportRuleImpl.deinit(instance);
    }

    pub fn get_href(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try CSSImportRuleImpl.get_href(instance);
    }

    /// Extended attributes: [SameObject], [PutForwards=mediaText]
    pub fn get_media(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_media) |cached| {
            return cached;
        }
        const value = try CSSImportRuleImpl.get_media(instance);
        state.own.cached_media = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_styleSheet(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_styleSheet) |cached| {
            return cached;
        }
        const value = try CSSImportRuleImpl.get_styleSheet(instance);
        state.own.cached_styleSheet = value;
        return value;
    }

    pub fn get_layerName(instance: *runtime.Instance) anyerror!?CSSOMString {
        return try CSSImportRuleImpl.get_layerName(instance);
    }

    pub fn get_supportsText(instance: *runtime.Instance) anyerror!?CSSOMString {
        return try CSSImportRuleImpl.get_supportsText(instance);
    }
};
