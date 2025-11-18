//! Generated from: cssom.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const StyleSheetImpl = @import("../impls/StyleSheet.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        StyleSheetImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        StyleSheetImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return StyleSheetImpl.get_type(state);
    }

    pub fn get_href(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return StyleSheetImpl.get_href(state);
    }

    pub fn get_ownerNode(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return StyleSheetImpl.get_ownerNode(state);
    }

    pub fn get_parentStyleSheet(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return StyleSheetImpl.get_parentStyleSheet(state);
    }

    pub fn get_title(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return StyleSheetImpl.get_title(state);
    }

    /// Extended attributes: [SameObject], [PutForwards=mediaText]
    pub fn get_media(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_media) |cached| {
            return cached;
        }
        const value = StyleSheetImpl.get_media(state);
        state.cached_media = value;
        return value;
    }

    pub fn get_disabled(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return StyleSheetImpl.get_disabled(state);
    }

    pub fn set_disabled(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        StyleSheetImpl.set_disabled(state, value);
    }

    pub fn get_type(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return StyleSheetImpl.get_type(state);
    }

    pub fn get_disabled(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return StyleSheetImpl.get_disabled(state);
    }

    pub fn set_disabled(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        StyleSheetImpl.set_disabled(state, value);
    }

    pub fn get_ownerNode(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return StyleSheetImpl.get_ownerNode(state);
    }

    pub fn get_parentStyleSheet(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return StyleSheetImpl.get_parentStyleSheet(state);
    }

    pub fn get_href(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return StyleSheetImpl.get_href(state);
    }

    pub fn get_title(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return StyleSheetImpl.get_title(state);
    }

    pub fn get_media(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return StyleSheetImpl.get_media(state);
    }

};
