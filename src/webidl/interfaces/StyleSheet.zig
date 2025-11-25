//! Generated from: cssom.idl
//! Generated at: 2025-11-25T20:02:33Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const StyleSheetImpl = @import("impls").StyleSheet;
const Element = @import("interfaces").Element;
const CSSStyleSheet = @import("interfaces").CSSStyleSheet;
const CSSOMString = @import("typedefs").CSSOMString;
const ProcessingInstruction = @import("interfaces").ProcessingInstruction;
const Node = @import("interfaces").Node;
const USVString = @import("interfaces").USVString;
const DOMString = @import("typedefs").DOMString;
const MediaList = @import("interfaces").MediaList;

pub const StyleSheet = struct {
    pub const Meta = struct {
        pub const name = "StyleSheet";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "type", "get_type", null },
            .{ "href", "get_href", null },
            .{ "ownerNode", "get_ownerNode", null },
            .{ "parentStyleSheet", "get_parentStyleSheet", null },
            .{ "title", "get_title", null },
            .{ "media", "get_media", null },
            .{ "disabled", "get_disabled", "set_disabled" },
            .{ "type", "get_type", null },
            .{ "disabled", "get_disabled", "set_disabled" },
            .{ "ownerNode", "get_ownerNode", null },
            .{ "parentStyleSheet", "get_parentStyleSheet", null },
            .{ "href", "get_href", null },
            .{ "title", "get_title", null },
            .{ "media", "get_media", null },
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
            .{ "type", "get_type", null },
            .{ "href", "get_href", null },
            .{ "ownerNode", "get_ownerNode", null },
            .{ "parentStyleSheet", "get_parentStyleSheet", null },
            .{ "title", "get_title", null },
            .{ "media", "get_media", null },
            .{ "disabled", "get_disabled", "set_disabled" },
            .{ "type", "get_type", null },
            .{ "disabled", "get_disabled", "set_disabled" },
            .{ "ownerNode", "get_ownerNode", null },
            .{ "parentStyleSheet", "get_parentStyleSheet", null },
            .{ "href", "get_href", null },
            .{ "title", "get_title", null },
            .{ "media", "get_media", null },
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
            @"type": CSSOMString = undefined,
            href: ?runtime.USVString = null,
            ownerNode: ?union(enum) {
                Element: Element,
                ProcessingInstruction: ProcessingInstruction,
            } = null,
            parentStyleSheet: ?*runtime.Instance = null,
            title: ?runtime.DOMString = null,
            media: *runtime.Instance = undefined,
            disabled: bool = undefined,
            cached_media: ?*runtime.Instance = null,
            _internal: ?*StyleSheetImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_disabled = &get_disabled,
        .get_href = &get_href,
        .get_media = &get_media,
        .get_ownerNode = &get_ownerNode,
        .get_parentStyleSheet = &get_parentStyleSheet,
        .get_title = &get_title,
        .get_type = &get_type,

        .set_disabled = &set_disabled,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return StyleSheetImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        StyleSheetImpl.deinit(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!CSSOMString {
        return try StyleSheetImpl.get_type(instance);
    }

    pub fn get_href(instance: *runtime.Instance) anyerror!?runtime.USVString {
        return try StyleSheetImpl.get_href(instance);
    }

    pub fn get_ownerNode(instance: *runtime.Instance) anyerror!?*const anyopaque {
        return try StyleSheetImpl.get_ownerNode(instance);
    }

    pub fn get_parentStyleSheet(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try StyleSheetImpl.get_parentStyleSheet(instance);
    }

    pub fn get_title(instance: *runtime.Instance) anyerror!?DOMString {
        return try StyleSheetImpl.get_title(instance);
    }

    /// Extended attributes: [SameObject], [PutForwards=mediaText]
    pub fn get_media(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_media) |cached| {
            return cached;
        }
        const value = try StyleSheetImpl.get_media(instance);
        state.own.cached_media = value;
        return value;
    }

    pub fn get_disabled(instance: *runtime.Instance) anyerror!bool {
        return try StyleSheetImpl.get_disabled(instance);
    }

    pub fn set_disabled(instance: *runtime.Instance, value: bool) anyerror!void {
        try StyleSheetImpl.set_disabled(instance, value);
    }

};
