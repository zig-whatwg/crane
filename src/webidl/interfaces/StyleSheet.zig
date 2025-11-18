//! Generated from: cssom.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const StyleSheetImpl = @import("impls").StyleSheet;
const (Element or ProcessingInstruction) = @import("interfaces").(Element or ProcessingInstruction);
const CSSStyleSheet = @import("interfaces").CSSStyleSheet;
const CSSOMString = @import("interfaces").CSSOMString;
const Node = @import("interfaces").Node;
const USVString = @import("interfaces").USVString;
const DOMString = @import("typedefs").DOMString;
const MediaList = @import("interfaces").MediaList;

pub const StyleSheet = struct {
    pub const Meta = struct {
        pub const name = "StyleSheet";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            type: CSSOMString = undefined,
            href: ?runtime.USVString = null,
            ownerNode: ?(Element or ProcessingInstruction) = null,
            parentStyleSheet: ?CSSStyleSheet = null,
            title: ?runtime.DOMString = null,
            media: MediaList = undefined,
            disabled: bool = undefined,
            type: runtime.DOMString = undefined,
            disabled: bool = undefined,
            ownerNode: Node = undefined,
            parentStyleSheet: StyleSheet = undefined,
            href: runtime.DOMString = undefined,
            title: runtime.DOMString = undefined,
            media: MediaList = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(StyleSheet, .{
        .deinit_fn = &deinit_wrapper,

        .get_disabled = &get_disabled,
        .get_disabled = &get_disabled,
        .get_href = &get_href,
        .get_href = &get_href,
        .get_media = &get_media,
        .get_media = &get_media,
        .get_ownerNode = &get_ownerNode,
        .get_ownerNode = &get_ownerNode,
        .get_parentStyleSheet = &get_parentStyleSheet,
        .get_parentStyleSheet = &get_parentStyleSheet,
        .get_title = &get_title,
        .get_title = &get_title,
        .get_type = &get_type,
        .get_type = &get_type,

        .set_disabled = &set_disabled,
        .set_disabled = &set_disabled,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        StyleSheetImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        StyleSheetImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!anyopaque {
        return try StyleSheetImpl.get_type(instance);
    }

    pub fn get_href(instance: *runtime.Instance) anyerror!anyopaque {
        return try StyleSheetImpl.get_href(instance);
    }

    pub fn get_ownerNode(instance: *runtime.Instance) anyerror!anyopaque {
        return try StyleSheetImpl.get_ownerNode(instance);
    }

    pub fn get_parentStyleSheet(instance: *runtime.Instance) anyerror!anyopaque {
        return try StyleSheetImpl.get_parentStyleSheet(instance);
    }

    pub fn get_title(instance: *runtime.Instance) anyerror!anyopaque {
        return try StyleSheetImpl.get_title(instance);
    }

    /// Extended attributes: [SameObject], [PutForwards=mediaText]
    pub fn get_media(instance: *runtime.Instance) anyerror!MediaList {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_media) |cached| {
            return cached;
        }
        const value = try StyleSheetImpl.get_media(instance);
        state.cached_media = value;
        return value;
    }

    pub fn get_disabled(instance: *runtime.Instance) anyerror!bool {
        return try StyleSheetImpl.get_disabled(instance);
    }

    pub fn set_disabled(instance: *runtime.Instance, value: bool) anyerror!void {
        try StyleSheetImpl.set_disabled(instance, value);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!DOMString {
        return try StyleSheetImpl.get_type(instance);
    }

    pub fn get_disabled(instance: *runtime.Instance) anyerror!bool {
        return try StyleSheetImpl.get_disabled(instance);
    }

    pub fn set_disabled(instance: *runtime.Instance, value: bool) anyerror!void {
        try StyleSheetImpl.set_disabled(instance, value);
    }

    pub fn get_ownerNode(instance: *runtime.Instance) anyerror!Node {
        return try StyleSheetImpl.get_ownerNode(instance);
    }

    pub fn get_parentStyleSheet(instance: *runtime.Instance) anyerror!StyleSheet {
        return try StyleSheetImpl.get_parentStyleSheet(instance);
    }

    pub fn get_href(instance: *runtime.Instance) anyerror!DOMString {
        return try StyleSheetImpl.get_href(instance);
    }

    pub fn get_title(instance: *runtime.Instance) anyerror!DOMString {
        return try StyleSheetImpl.get_title(instance);
    }

    pub fn get_media(instance: *runtime.Instance) anyerror!MediaList {
        return try StyleSheetImpl.get_media(instance);
    }

};
