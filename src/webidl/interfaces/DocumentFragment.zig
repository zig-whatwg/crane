//! Generated from: dom.idl
//! Generated at: 2025-11-28T19:51:33Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const DocumentFragmentImpl = @import("impls").DocumentFragment;
const mixins = @import("mixins");
const Node = @import("interfaces").Node;
const NonElementParentNode = @import("interfaces").NonElementParentNode;
const ParentNode = @import("interfaces").ParentNode;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const Document = @import("interfaces").Document;
const HTMLCollection = @import("interfaces").HTMLCollection;
const NodeList = @import("interfaces").NodeList;
const USVString = @import("interfaces").USVString;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const Element = @import("interfaces").Element;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const GetRootNodeOptions = @import("dictionaries").GetRootNodeOptions;
const DOMString = @import("typedefs").DOMString;

pub const DocumentFragment = struct {
    pub const Meta = struct {
        pub const name = "DocumentFragment";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Node;
        pub const MixinTypes = &.{
            NonElementParentNode,
            ParentNode,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "children", "get_children", null },
            .{ "firstElementChild", "get_firstElementChild", null },
            .{ "lastElementChild", "get_lastElementChild", null },
            .{ "childElementCount", "get_childElementCount", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getElementById", "call_getElementById", 1 },
            .{ "prepend", "call_prepend", 1 },
            .{ "append", "call_append", 1 },
            .{ "replaceChildren", "call_replaceChildren", 1 },
            .{ "moveBefore", "call_moveBefore", 2 },
            .{ "querySelector", "call_querySelector", 1 },
            .{ "querySelectorAll", "call_querySelectorAll", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getElementById",
            "prepend",
            "append",
            "replaceChildren",
            "moveBefore",
            "querySelector",
            "querySelectorAll",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
            "getRootNode",
            "hasChildNodes",
            "normalize",
            "cloneNode",
            "isEqualNode",
            "isSameNode",
            "compareDocumentPosition",
            "contains",
            "lookupPrefix",
            "lookupNamespaceURI",
            "isDefaultNamespace",
            "insertBefore",
            "appendChild",
            "replaceChild",
            "removeChild",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "children", "get_children", null },
            .{ "firstElementChild", "get_firstElementChild", null },
            .{ "lastElementChild", "get_lastElementChild", null },
            .{ "childElementCount", "get_childElementCount", null },
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
            children: *runtime.Instance = undefined,
            firstElementChild: ?*runtime.Instance = null,
            lastElementChild: ?*runtime.Instance = null,
            childElementCount: u32 = undefined,
            cached_children: ?*runtime.Instance = null,
            _internal: ?*DocumentFragmentImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_childElementCount = &get_childElementCount,
        .get_children = &get_children,
        .get_firstElementChild = &get_firstElementChild,
        .get_lastElementChild = &get_lastElementChild,

        .call_append = &call_append,
        .call_getElementById = &call_getElementById,
        .call_moveBefore = &call_moveBefore,
        .call_prepend = &call_prepend,
        .call_querySelector = &call_querySelector,
        .call_querySelectorAll = &call_querySelectorAll,
        .call_replaceChildren = &call_replaceChildren,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return DocumentFragmentImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DocumentFragmentImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try DocumentFragmentImpl.call_constructor(allocator, ctx);
    }

    /// Extended attributes: [SameObject]
    pub fn get_children(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_children) |cached| {
            return cached;
        }
        const value = try DocumentFragmentImpl.get_children(instance);
        state.own.cached_children = value;
        return value;
    }

    pub fn get_firstElementChild(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try DocumentFragmentImpl.get_firstElementChild(instance);
    }

    pub fn get_lastElementChild(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try DocumentFragmentImpl.get_lastElementChild(instance);
    }

    pub fn get_childElementCount(instance: *runtime.Instance) anyerror!u32 {
        return try DocumentFragmentImpl.get_childElementCount(instance);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_append(instance: *runtime.Instance, nodes: []const mixins.ParentNode.NodeOrString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try DocumentFragmentImpl.call_append(instance, nodes);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_replaceChildren(instance: *runtime.Instance, nodes: []const mixins.ParentNode.NodeOrString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try DocumentFragmentImpl.call_replaceChildren(instance, nodes);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_moveBefore(instance: *runtime.Instance, node: *runtime.Instance, child: ?*runtime.Instance) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try DocumentFragmentImpl.call_moveBefore(instance, node, child);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_prepend(instance: *runtime.Instance, nodes: []const mixins.ParentNode.NodeOrString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try DocumentFragmentImpl.call_prepend(instance, nodes);
    }

    pub fn call_querySelector(instance: *runtime.Instance, selectors: DOMString) anyerror!?*runtime.Instance {
        
        return try DocumentFragmentImpl.call_querySelector(instance, selectors);
    }

    /// Extended attributes: [NewObject]
    pub fn call_querySelectorAll(instance: *runtime.Instance, selectors: DOMString) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try DocumentFragmentImpl.call_querySelectorAll(instance, selectors);
    }

    pub fn call_getElementById(instance: *runtime.Instance, elementId: DOMString) anyerror!?*runtime.Instance {
        
        return try DocumentFragmentImpl.call_getElementById(instance, elementId);
    }

};
