//! Generated from: selection-api.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SelectionImpl = @import("impls").Selection;
const Node = @import("interfaces").Node;
const GetComposedRangesOptions = @import("dictionaries").GetComposedRangesOptions;
const Range = @import("interfaces").Range;

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
        
        // Initialize the instance (Impl receives full instance)
        SelectionImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SelectionImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_anchorNode(instance: *runtime.Instance) anyerror!anyopaque {
        return try SelectionImpl.get_anchorNode(instance);
    }

    pub fn get_anchorOffset(instance: *runtime.Instance) anyerror!u32 {
        return try SelectionImpl.get_anchorOffset(instance);
    }

    pub fn get_focusNode(instance: *runtime.Instance) anyerror!anyopaque {
        return try SelectionImpl.get_focusNode(instance);
    }

    pub fn get_focusOffset(instance: *runtime.Instance) anyerror!u32 {
        return try SelectionImpl.get_focusOffset(instance);
    }

    pub fn get_isCollapsed(instance: *runtime.Instance) anyerror!bool {
        return try SelectionImpl.get_isCollapsed(instance);
    }

    pub fn get_rangeCount(instance: *runtime.Instance) anyerror!u32 {
        return try SelectionImpl.get_rangeCount(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!DOMString {
        return try SelectionImpl.get_type(instance);
    }

    pub fn get_direction(instance: *runtime.Instance) anyerror!DOMString {
        return try SelectionImpl.get_direction(instance);
    }

    pub fn call_setPosition(instance: *runtime.Instance, node: anyopaque, offset: u32) anyerror!void {
        
        return try SelectionImpl.call_setPosition(instance, node, offset);
    }

    pub fn call_removeAllRanges(instance: *runtime.Instance) anyerror!void {
        return try SelectionImpl.call_removeAllRanges(instance);
    }

    pub fn call_selectAllChildren(instance: *runtime.Instance, node: Node) anyerror!void {
        
        return try SelectionImpl.call_selectAllChildren(instance, node);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_deleteFromDocument(instance: *runtime.Instance) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        return try SelectionImpl.call_deleteFromDocument(instance);
    }

    pub fn call_empty(instance: *runtime.Instance) anyerror!void {
        return try SelectionImpl.call_empty(instance);
    }

    pub fn call_collapseToEnd(instance: *runtime.Instance) anyerror!void {
        return try SelectionImpl.call_collapseToEnd(instance);
    }

    pub fn call_getComposedRanges(instance: *runtime.Instance, options: GetComposedRangesOptions) anyerror!anyopaque {
        
        return try SelectionImpl.call_getComposedRanges(instance, options);
    }

    pub fn call_collapse(instance: *runtime.Instance, node: anyopaque, offset: u32) anyerror!void {
        
        return try SelectionImpl.call_collapse(instance, node, offset);
    }

    pub fn call_extend(instance: *runtime.Instance, node: Node, offset: u32) anyerror!void {
        
        return try SelectionImpl.call_extend(instance, node, offset);
    }

    pub fn call_collapseToStart(instance: *runtime.Instance) anyerror!void {
        return try SelectionImpl.call_collapseToStart(instance);
    }

    pub fn call_addRange(instance: *runtime.Instance, range: Range) anyerror!void {
        
        return try SelectionImpl.call_addRange(instance, range);
    }

    pub fn call_setBaseAndExtent(instance: *runtime.Instance, anchorNode: Node, anchorOffset: u32, focusNode: Node, focusOffset: u32) anyerror!void {
        
        return try SelectionImpl.call_setBaseAndExtent(instance, anchorNode, anchorOffset, focusNode, focusOffset);
    }

    pub fn call_getRangeAt(instance: *runtime.Instance, index: u32) anyerror!Range {
        
        return try SelectionImpl.call_getRangeAt(instance, index);
    }

    pub fn call_modify(instance: *runtime.Instance, alter: DOMString, direction: DOMString, granularity: DOMString) anyerror!void {
        
        return try SelectionImpl.call_modify(instance, alter, direction, granularity);
    }

    pub fn call_containsNode(instance: *runtime.Instance, node: Node, allowPartialContainment: bool) anyerror!bool {
        
        return try SelectionImpl.call_containsNode(instance, node, allowPartialContainment);
    }

    pub fn call_removeRange(instance: *runtime.Instance, range: Range) anyerror!void {
        
        return try SelectionImpl.call_removeRange(instance, range);
    }

};
