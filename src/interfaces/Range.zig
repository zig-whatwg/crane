//! Generated from: dom.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RangeImpl = @import("../impls/Range.zig");
const AbstractRange = @import("AbstractRange.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        RangeImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        RangeImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try RangeImpl.constructor(state);
        
        return instance;
    }

    pub fn get_startContainer(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RangeImpl.get_startContainer(state);
    }

    pub fn get_startOffset(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return RangeImpl.get_startOffset(state);
    }

    pub fn get_endContainer(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RangeImpl.get_endContainer(state);
    }

    pub fn get_endOffset(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return RangeImpl.get_endOffset(state);
    }

    pub fn get_collapsed(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return RangeImpl.get_collapsed(state);
    }

    pub fn get_commonAncestorContainer(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RangeImpl.get_commonAncestorContainer(state);
    }

    pub fn call_setStartBefore(instance: *runtime.Instance, node: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return RangeImpl.call_setStartBefore(state, node);
    }

    pub fn call_setEndBefore(instance: *runtime.Instance, node: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return RangeImpl.call_setEndBefore(state, node);
    }

    /// Extended attributes: [CEReactions], [NewObject]
    pub fn call_extractContents(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        // [NewObject] - Caller owns the returned object
        return RangeImpl.call_extractContents(state);
    }

    pub fn call_selectNode(instance: *runtime.Instance, node: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return RangeImpl.call_selectNode(state, node);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_surroundContents(instance: *runtime.Instance, newParent: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return RangeImpl.call_surroundContents(state, newParent);
    }

    pub fn call_detach(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RangeImpl.call_detach(state);
    }

    pub fn call_isPointInRange(instance: *runtime.Instance, node: anyopaque, offset: u32) bool {
        const state = instance.getState(State);
        
        return RangeImpl.call_isPointInRange(state, node, offset);
    }

    pub fn call_setEndAfter(instance: *runtime.Instance, node: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return RangeImpl.call_setEndAfter(state, node);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_insertNode(instance: *runtime.Instance, node: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return RangeImpl.call_insertNode(state, node);
    }

    pub fn call_setEnd(instance: *runtime.Instance, node: anyopaque, offset: u32) anyopaque {
        const state = instance.getState(State);
        
        return RangeImpl.call_setEnd(state, node, offset);
    }

    pub fn call_setStartAfter(instance: *runtime.Instance, node: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return RangeImpl.call_setStartAfter(state, node);
    }

    pub fn call_selectNodeContents(instance: *runtime.Instance, node: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return RangeImpl.call_selectNodeContents(state, node);
    }

    /// Extended attributes: [CEReactions], [NewObject]
    pub fn call_createContextualFragment(instance: *runtime.Instance, string: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        // [NewObject] - Caller owns the returned object
        
        return RangeImpl.call_createContextualFragment(state, string);
    }

    pub fn call_collapse(instance: *runtime.Instance, toStart: bool) anyopaque {
        const state = instance.getState(State);
        
        return RangeImpl.call_collapse(state, toStart);
    }

    pub fn call_comparePoint(instance: *runtime.Instance, node: anyopaque, offset: u32) i16 {
        const state = instance.getState(State);
        
        return RangeImpl.call_comparePoint(state, node, offset);
    }

    pub fn call_getClientRects(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RangeImpl.call_getClientRects(state);
    }

    /// Extended attributes: [NewObject]
    pub fn call_cloneRange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        return RangeImpl.call_cloneRange(state);
    }

    pub fn call_setStart(instance: *runtime.Instance, node: anyopaque, offset: u32) anyopaque {
        const state = instance.getState(State);
        
        return RangeImpl.call_setStart(state, node, offset);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_deleteContents(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        return RangeImpl.call_deleteContents(state);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getBoundingClientRect(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        return RangeImpl.call_getBoundingClientRect(state);
    }

    /// Extended attributes: [CEReactions], [NewObject]
    pub fn call_cloneContents(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        // [NewObject] - Caller owns the returned object
        return RangeImpl.call_cloneContents(state);
    }

    pub fn call_intersectsNode(instance: *runtime.Instance, node: anyopaque) bool {
        const state = instance.getState(State);
        
        return RangeImpl.call_intersectsNode(state, node);
    }

    pub fn call_compareBoundaryPoints(instance: *runtime.Instance, how: u16, sourceRange: anyopaque) i16 {
        const state = instance.getState(State);
        
        return RangeImpl.call_compareBoundaryPoints(state, how, sourceRange);
    }

};
