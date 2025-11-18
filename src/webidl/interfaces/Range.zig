//! Generated from: dom.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RangeImpl = @import("impls").Range;
const AbstractRange = @import("interfaces").AbstractRange;
const DocumentFragment = @import("interfaces").DocumentFragment;
const DOMRect = @import("interfaces").DOMRect;
const Node = @import("interfaces").Node;
const DOMRectList = @import("interfaces").DOMRectList;
const (TrustedHTML or DOMString) = @import("interfaces").(TrustedHTML or DOMString);

pub const Range = struct {
    pub const Meta = struct {
        pub const name = "Range";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *AbstractRange;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            commonAncestorContainer: Node = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const unsigned short START_TO_START = 0;
    pub fn get_START_TO_START() u16 {
        return 0;
    }

    /// WebIDL constant: const unsigned short START_TO_END = 1;
    pub fn get_START_TO_END() u16 {
        return 1;
    }

    /// WebIDL constant: const unsigned short END_TO_END = 2;
    pub fn get_END_TO_END() u16 {
        return 2;
    }

    /// WebIDL constant: const unsigned short END_TO_START = 3;
    pub fn get_END_TO_START() u16 {
        return 3;
    }

    pub const vtable = runtime.buildVTable(Range, .{
        .deinit_fn = &deinit_wrapper,

        .get_END_TO_END = &get_END_TO_END,
        .get_END_TO_START = &get_END_TO_START,
        .get_START_TO_END = &get_START_TO_END,
        .get_START_TO_START = &get_START_TO_START,
        .get_collapsed = &get_collapsed,
        .get_commonAncestorContainer = &get_commonAncestorContainer,
        .get_endContainer = &get_endContainer,
        .get_endOffset = &get_endOffset,
        .get_startContainer = &get_startContainer,
        .get_startOffset = &get_startOffset,

        .call_cloneContents = &call_cloneContents,
        .call_cloneRange = &call_cloneRange,
        .call_collapse = &call_collapse,
        .call_compareBoundaryPoints = &call_compareBoundaryPoints,
        .call_comparePoint = &call_comparePoint,
        .call_createContextualFragment = &call_createContextualFragment,
        .call_deleteContents = &call_deleteContents,
        .call_detach = &call_detach,
        .call_extractContents = &call_extractContents,
        .call_getBoundingClientRect = &call_getBoundingClientRect,
        .call_getClientRects = &call_getClientRects,
        .call_insertNode = &call_insertNode,
        .call_intersectsNode = &call_intersectsNode,
        .call_isPointInRange = &call_isPointInRange,
        .call_selectNode = &call_selectNode,
        .call_selectNodeContents = &call_selectNodeContents,
        .call_setEnd = &call_setEnd,
        .call_setEndAfter = &call_setEndAfter,
        .call_setEndBefore = &call_setEndBefore,
        .call_setStart = &call_setStart,
        .call_setStartAfter = &call_setStartAfter,
        .call_setStartBefore = &call_setStartBefore,
        .call_surroundContents = &call_surroundContents,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        RangeImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RangeImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try RangeImpl.constructor(instance);
        
        return instance;
    }

    pub fn get_startContainer(instance: *runtime.Instance) anyerror!Node {
        return try RangeImpl.get_startContainer(instance);
    }

    pub fn get_startOffset(instance: *runtime.Instance) anyerror!u32 {
        return try RangeImpl.get_startOffset(instance);
    }

    pub fn get_endContainer(instance: *runtime.Instance) anyerror!Node {
        return try RangeImpl.get_endContainer(instance);
    }

    pub fn get_endOffset(instance: *runtime.Instance) anyerror!u32 {
        return try RangeImpl.get_endOffset(instance);
    }

    pub fn get_collapsed(instance: *runtime.Instance) anyerror!bool {
        return try RangeImpl.get_collapsed(instance);
    }

    pub fn get_commonAncestorContainer(instance: *runtime.Instance) anyerror!Node {
        return try RangeImpl.get_commonAncestorContainer(instance);
    }

    pub fn call_setStartBefore(instance: *runtime.Instance, node: Node) anyerror!void {
        
        return try RangeImpl.call_setStartBefore(instance, node);
    }

    pub fn call_setEndBefore(instance: *runtime.Instance, node: Node) anyerror!void {
        
        return try RangeImpl.call_setEndBefore(instance, node);
    }

    /// Extended attributes: [CEReactions], [NewObject]
    pub fn call_extractContents(instance: *runtime.Instance) anyerror!DocumentFragment {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        // [NewObject] - Caller owns the returned object
        return try RangeImpl.call_extractContents(instance);
    }

    pub fn call_selectNode(instance: *runtime.Instance, node: Node) anyerror!void {
        
        return try RangeImpl.call_selectNode(instance, node);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_surroundContents(instance: *runtime.Instance, newParent: Node) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try RangeImpl.call_surroundContents(instance, newParent);
    }

    pub fn call_detach(instance: *runtime.Instance) anyerror!void {
        return try RangeImpl.call_detach(instance);
    }

    pub fn call_isPointInRange(instance: *runtime.Instance, node: Node, offset: u32) anyerror!bool {
        
        return try RangeImpl.call_isPointInRange(instance, node, offset);
    }

    pub fn call_setEndAfter(instance: *runtime.Instance, node: Node) anyerror!void {
        
        return try RangeImpl.call_setEndAfter(instance, node);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_insertNode(instance: *runtime.Instance, node: Node) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try RangeImpl.call_insertNode(instance, node);
    }

    pub fn call_setEnd(instance: *runtime.Instance, node: Node, offset: u32) anyerror!void {
        
        return try RangeImpl.call_setEnd(instance, node, offset);
    }

    pub fn call_setStartAfter(instance: *runtime.Instance, node: Node) anyerror!void {
        
        return try RangeImpl.call_setStartAfter(instance, node);
    }

    pub fn call_selectNodeContents(instance: *runtime.Instance, node: Node) anyerror!void {
        
        return try RangeImpl.call_selectNodeContents(instance, node);
    }

    /// Extended attributes: [CEReactions], [NewObject]
    pub fn call_createContextualFragment(instance: *runtime.Instance, string: anyopaque) anyerror!DocumentFragment {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        // [NewObject] - Caller owns the returned object
        
        return try RangeImpl.call_createContextualFragment(instance, string);
    }

    pub fn call_collapse(instance: *runtime.Instance, toStart: bool) anyerror!void {
        
        return try RangeImpl.call_collapse(instance, toStart);
    }

    pub fn call_comparePoint(instance: *runtime.Instance, node: Node, offset: u32) anyerror!i16 {
        
        return try RangeImpl.call_comparePoint(instance, node, offset);
    }

    pub fn call_getClientRects(instance: *runtime.Instance) anyerror!DOMRectList {
        return try RangeImpl.call_getClientRects(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_cloneRange(instance: *runtime.Instance) anyerror!Range {
        // [NewObject] - Caller owns the returned object
        return try RangeImpl.call_cloneRange(instance);
    }

    pub fn call_setStart(instance: *runtime.Instance, node: Node, offset: u32) anyerror!void {
        
        return try RangeImpl.call_setStart(instance, node, offset);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_deleteContents(instance: *runtime.Instance) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        return try RangeImpl.call_deleteContents(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getBoundingClientRect(instance: *runtime.Instance) anyerror!DOMRect {
        // [NewObject] - Caller owns the returned object
        return try RangeImpl.call_getBoundingClientRect(instance);
    }

    /// Extended attributes: [CEReactions], [NewObject]
    pub fn call_cloneContents(instance: *runtime.Instance) anyerror!DocumentFragment {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        // [NewObject] - Caller owns the returned object
        return try RangeImpl.call_cloneContents(instance);
    }

    pub fn call_intersectsNode(instance: *runtime.Instance, node: Node) anyerror!bool {
        
        return try RangeImpl.call_intersectsNode(instance, node);
    }

    pub fn call_compareBoundaryPoints(instance: *runtime.Instance, how: u16, sourceRange: Range) anyerror!i16 {
        
        return try RangeImpl.call_compareBoundaryPoints(instance, how, sourceRange);
    }

};
