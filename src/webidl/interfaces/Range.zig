//! Generated from: dom.idl
//! Generated at: 2025-12-07T20:02:42Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const RangeImpl = @import("impls").Range;
const mixins = @import("mixins");
const AbstractRange = @import("interfaces").AbstractRange;
const DocumentFragment = @import("interfaces").DocumentFragment;
const DOMRect = @import("interfaces").DOMRect;
const TrustedHTML = @import("interfaces").TrustedHTML;
const Node = @import("interfaces").Node;
const DOMRectList = @import("interfaces").DOMRectList;
const DOMString = @import("typedefs").DOMString;

pub const Range = struct {
    pub const Meta = struct {
        pub const name = "Range";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = AbstractRange.State;
        pub const ParentInterface = AbstractRange;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "commonAncestorContainer", "get_commonAncestorContainer", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "setStart", "call_setStart", 2 },
            .{ "setEnd", "call_setEnd", 2 },
            .{ "setStartBefore", "call_setStartBefore", 1 },
            .{ "setStartAfter", "call_setStartAfter", 1 },
            .{ "setEndBefore", "call_setEndBefore", 1 },
            .{ "setEndAfter", "call_setEndAfter", 1 },
            .{ "collapse", "call_collapse", 0 },
            .{ "selectNode", "call_selectNode", 1 },
            .{ "selectNodeContents", "call_selectNodeContents", 1 },
            .{ "compareBoundaryPoints", "call_compareBoundaryPoints", 2 },
            .{ "deleteContents", "call_deleteContents", 0 },
            .{ "extractContents", "call_extractContents", 0 },
            .{ "cloneContents", "call_cloneContents", 0 },
            .{ "insertNode", "call_insertNode", 1 },
            .{ "surroundContents", "call_surroundContents", 1 },
            .{ "cloneRange", "call_cloneRange", 0 },
            .{ "detach", "call_detach", 0 },
            .{ "isPointInRange", "call_isPointInRange", 2 },
            .{ "comparePoint", "call_comparePoint", 2 },
            .{ "intersectsNode", "call_intersectsNode", 1 },
            .{ "createContextualFragment", "call_createContextualFragment", 1 },
            .{ "getClientRects", "call_getClientRects", 0 },
            .{ "getBoundingClientRect", "call_getBoundingClientRect", 0 },
        };
        
        /// Constants binding hints for V8Interface (JS name, getter fn name)
        pub const constants = .{
            .{ "START_TO_START", "get_START_TO_START" },
            .{ "START_TO_END", "get_START_TO_END" },
            .{ "END_TO_END", "get_END_TO_END" },
            .{ "END_TO_START", "get_END_TO_START" },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "setStart",
            "setEnd",
            "setStartBefore",
            "setStartAfter",
            "setEndBefore",
            "setEndAfter",
            "collapse",
            "selectNode",
            "selectNodeContents",
            "compareBoundaryPoints",
            "deleteContents",
            "extractContents",
            "cloneContents",
            "insertNode",
            "surroundContents",
            "cloneRange",
            "detach",
            "isPointInRange",
            "comparePoint",
            "intersectsNode",
            "createContextualFragment",
            "getClientRects",
            "getBoundingClientRect",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "commonAncestorContainer", "get_commonAncestorContainer", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            commonAncestorContainer: *runtime.Instance = undefined,
            _internal: ?*RangeImpl.InternalState = null,
        },
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

    const delegates = .{

        .get_END_TO_END = &get_END_TO_END,
        .get_END_TO_START = &get_END_TO_START,
        .get_START_TO_END = &get_START_TO_END,
        .get_START_TO_START = &get_START_TO_START,
        .get_commonAncestorContainer = &get_commonAncestorContainer,

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

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return RangeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RangeImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try RangeImpl.call_constructor(allocator, ctx);
    }

    pub fn get_commonAncestorContainer(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try RangeImpl.get_commonAncestorContainer(instance);
    }

    pub fn call_setStartBefore(instance: *runtime.Instance, node: *runtime.Instance) anyerror!void {
        
        return try RangeImpl.call_setStartBefore(instance, node);
    }

    pub fn call_setEndBefore(instance: *runtime.Instance, node: *runtime.Instance) anyerror!void {
        
        return try RangeImpl.call_setEndBefore(instance, node);
    }

    /// Extended attributes: [CEReactions], [NewObject]
    pub fn call_extractContents(instance: *runtime.Instance) anyerror!*runtime.Instance {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        // [NewObject] - Caller owns the returned object
        return try RangeImpl.call_extractContents(instance);
    }

    pub fn call_selectNode(instance: *runtime.Instance, node: *runtime.Instance) anyerror!void {
        
        return try RangeImpl.call_selectNode(instance, node);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_surroundContents(instance: *runtime.Instance, newParent: *runtime.Instance) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try RangeImpl.call_surroundContents(instance, newParent);
    }

    pub fn call_detach(instance: *runtime.Instance) anyerror!void {
        return try RangeImpl.call_detach(instance);
    }

    pub fn call_isPointInRange(instance: *runtime.Instance, node: *runtime.Instance, offset: u32) anyerror!bool {
        
        return try RangeImpl.call_isPointInRange(instance, node, offset);
    }

    pub fn call_setEndAfter(instance: *runtime.Instance, node: *runtime.Instance) anyerror!void {
        
        return try RangeImpl.call_setEndAfter(instance, node);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_insertNode(instance: *runtime.Instance, node: *runtime.Instance) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try RangeImpl.call_insertNode(instance, node);
    }

    pub fn call_setEnd(instance: *runtime.Instance, node: *runtime.Instance, offset: u32) anyerror!void {
        
        return try RangeImpl.call_setEnd(instance, node, offset);
    }

    pub fn call_setStartAfter(instance: *runtime.Instance, node: *runtime.Instance) anyerror!void {
        
        return try RangeImpl.call_setStartAfter(instance, node);
    }

    pub fn call_selectNodeContents(instance: *runtime.Instance, node: *runtime.Instance) anyerror!void {
        
        return try RangeImpl.call_selectNodeContents(instance, node);
    }

    /// Extended attributes: [CEReactions], [NewObject]
    pub fn call_createContextualFragment(instance: *runtime.Instance, string: DOMString) anyerror!*runtime.Instance {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        // [NewObject] - Caller owns the returned object
        
        return try RangeImpl.call_createContextualFragment(instance, string);
    }

    pub fn call_collapse(instance: *runtime.Instance, toStart: webidl.Opt(bool)) anyerror!void {
        
        return try RangeImpl.call_collapse(instance, toStart);
    }

    pub fn call_comparePoint(instance: *runtime.Instance, node: *runtime.Instance, offset: u32) anyerror!i16 {
        
        return try RangeImpl.call_comparePoint(instance, node, offset);
    }

    pub fn call_getClientRects(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try RangeImpl.call_getClientRects(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_cloneRange(instance: *runtime.Instance) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        return try RangeImpl.call_cloneRange(instance);
    }

    pub fn call_setStart(instance: *runtime.Instance, node: *runtime.Instance, offset: u32) anyerror!void {
        
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
    pub fn call_getBoundingClientRect(instance: *runtime.Instance) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        return try RangeImpl.call_getBoundingClientRect(instance);
    }

    /// Extended attributes: [CEReactions], [NewObject]
    pub fn call_cloneContents(instance: *runtime.Instance) anyerror!*runtime.Instance {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        // [NewObject] - Caller owns the returned object
        return try RangeImpl.call_cloneContents(instance);
    }

    pub fn call_intersectsNode(instance: *runtime.Instance, node: *runtime.Instance) anyerror!bool {
        
        return try RangeImpl.call_intersectsNode(instance, node);
    }

    pub fn call_compareBoundaryPoints(instance: *runtime.Instance, how: u16, sourceRange: *runtime.Instance) anyerror!i16 {
        
        return try RangeImpl.call_compareBoundaryPoints(instance, how, sourceRange);
    }

};
