//! Generated from: selection-api.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SelectionImpl = @import("../impls/Selection.zig");

pub const Selection = struct {
    pub const Meta = struct {
        pub const name = "Selection";
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
            anchorNode: ?Node = null,
            anchorOffset: u32 = undefined,
            focusNode: ?Node = null,
            focusOffset: u32 = undefined,
            isCollapsed: bool = undefined,
            rangeCount: u32 = undefined,
            type: runtime.DOMString = undefined,
            direction: runtime.DOMString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Selection, .{
        .deinit_fn = &deinit_wrapper,

        .get_anchorNode = &get_anchorNode,
        .get_anchorOffset = &get_anchorOffset,
        .get_direction = &get_direction,
        .get_focusNode = &get_focusNode,
        .get_focusOffset = &get_focusOffset,
        .get_isCollapsed = &get_isCollapsed,
        .get_rangeCount = &get_rangeCount,
        .get_type = &get_type,

        .call_addRange = &call_addRange,
        .call_collapse = &call_collapse,
        .call_collapseToEnd = &call_collapseToEnd,
        .call_collapseToStart = &call_collapseToStart,
        .call_containsNode = &call_containsNode,
        .call_deleteFromDocument = &call_deleteFromDocument,
        .call_empty = &call_empty,
        .call_extend = &call_extend,
        .call_getComposedRanges = &call_getComposedRanges,
        .call_getRangeAt = &call_getRangeAt,
        .call_modify = &call_modify,
        .call_removeAllRanges = &call_removeAllRanges,
        .call_removeRange = &call_removeRange,
        .call_selectAllChildren = &call_selectAllChildren,
        .call_setBaseAndExtent = &call_setBaseAndExtent,
        .call_setPosition = &call_setPosition,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        SelectionImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        SelectionImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_anchorNode(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SelectionImpl.get_anchorNode(state);
    }

    pub fn get_anchorOffset(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return SelectionImpl.get_anchorOffset(state);
    }

    pub fn get_focusNode(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SelectionImpl.get_focusNode(state);
    }

    pub fn get_focusOffset(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return SelectionImpl.get_focusOffset(state);
    }

    pub fn get_isCollapsed(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return SelectionImpl.get_isCollapsed(state);
    }

    pub fn get_rangeCount(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return SelectionImpl.get_rangeCount(state);
    }

    pub fn get_type(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return SelectionImpl.get_type(state);
    }

    pub fn get_direction(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return SelectionImpl.get_direction(state);
    }

    pub fn call_setPosition(instance: *runtime.Instance, node: anyopaque, offset: u32) anyopaque {
        const state = instance.getState(State);
        
        return SelectionImpl.call_setPosition(state, node, offset);
    }

    pub fn call_removeAllRanges(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SelectionImpl.call_removeAllRanges(state);
    }

    pub fn call_selectAllChildren(instance: *runtime.Instance, node: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SelectionImpl.call_selectAllChildren(state, node);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_deleteFromDocument(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        return SelectionImpl.call_deleteFromDocument(state);
    }

    pub fn call_empty(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SelectionImpl.call_empty(state);
    }

    pub fn call_collapseToEnd(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SelectionImpl.call_collapseToEnd(state);
    }

    pub fn call_getComposedRanges(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SelectionImpl.call_getComposedRanges(state, options);
    }

    pub fn call_collapse(instance: *runtime.Instance, node: anyopaque, offset: u32) anyopaque {
        const state = instance.getState(State);
        
        return SelectionImpl.call_collapse(state, node, offset);
    }

    pub fn call_extend(instance: *runtime.Instance, node: anyopaque, offset: u32) anyopaque {
        const state = instance.getState(State);
        
        return SelectionImpl.call_extend(state, node, offset);
    }

    pub fn call_collapseToStart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SelectionImpl.call_collapseToStart(state);
    }

    pub fn call_addRange(instance: *runtime.Instance, range: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SelectionImpl.call_addRange(state, range);
    }

    pub fn call_setBaseAndExtent(instance: *runtime.Instance, anchorNode: anyopaque, anchorOffset: u32, focusNode: anyopaque, focusOffset: u32) anyopaque {
        const state = instance.getState(State);
        
        return SelectionImpl.call_setBaseAndExtent(state, anchorNode, anchorOffset, focusNode, focusOffset);
    }

    pub fn call_getRangeAt(instance: *runtime.Instance, index: u32) anyopaque {
        const state = instance.getState(State);
        
        return SelectionImpl.call_getRangeAt(state, index);
    }

    pub fn call_modify(instance: *runtime.Instance, alter: runtime.DOMString, direction: runtime.DOMString, granularity: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return SelectionImpl.call_modify(state, alter, direction, granularity);
    }

    pub fn call_containsNode(instance: *runtime.Instance, node: anyopaque, allowPartialContainment: bool) bool {
        const state = instance.getState(State);
        
        return SelectionImpl.call_containsNode(state, node, allowPartialContainment);
    }

    pub fn call_removeRange(instance: *runtime.Instance, range: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SelectionImpl.call_removeRange(state, range);
    }

};
