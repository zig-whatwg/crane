//! Generated from: dom.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const DocumentTypeImpl = @import("impls").DocumentType;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Node = @import("Node.zig").Node;
const ChildNode = @import("mixins").ChildNode;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const Document = @import("Document.zig").Document;
const NodeList = @import("NodeList.zig").NodeList;
const USVString = @import("typedefs").USVString;
const Event = @import("Event.zig").Event;
const Observable = @import("Observable.zig").Observable;
const Element = @import("Element.zig").Element;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("EventListener.zig").EventListener;
const GetRootNodeOptions = @import("dictionaries").GetRootNodeOptions;
const DOMString = @import("typedefs").DOMString;

pub const DocumentType = struct {
    pub const Meta = struct {
        pub const name = "DocumentType";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = Node.State;
        pub const ParentInterface = Node;
        pub const MixinTypes = &.{
            ChildNode,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "name", "get_name", null },
            .{ "publicId", "get_publicId", null },
            .{ "systemId", "get_systemId", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "before", "call_before", 0 },
            .{ "after", "call_after", 0 },
            .{ "replaceWith", "call_replaceWith", 0 },
            .{ "remove", "call_remove", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "before",
            "after",
            "replaceWith",
            "remove",
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
            .{ "name", "get_name", null },
            .{ "publicId", "get_publicId", null },
            .{ "systemId", "get_systemId", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
        
        /// Members marked with [Unscopable] extended attribute
        pub const unscopables = .{
            "before",
            "after",
            "replaceWith",
            "remove",
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            name: typedefs.DOMString = undefined,
            publicId: typedefs.DOMString = undefined,
            systemId: typedefs.DOMString = undefined,
            _internal: ?*DocumentTypeImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_name = &get_name,
        .get_publicId = &get_publicId,
        .get_systemId = &get_systemId,

        .call_after = &call_after,
        .call_before = &call_before,
        .call_remove = &call_remove,
        .call_replaceWith = &call_replaceWith,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return DocumentTypeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return DocumentTypeImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DocumentTypeImpl.deinit(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try DocumentTypeImpl.get_name(instance);
    }

    pub fn get_publicId(instance: *runtime.Instance) anyerror!DOMString {
        return try DocumentTypeImpl.get_publicId(instance);
    }

    pub fn get_systemId(instance: *runtime.Instance) anyerror!DOMString {
        return try DocumentTypeImpl.get_systemId(instance);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_before(instance: *runtime.Instance, nodes: []const mixins.ParentNode.NodeOrString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try DocumentTypeImpl.call_before(instance, nodes);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_replaceWith(instance: *runtime.Instance, nodes: []const mixins.ParentNode.NodeOrString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try DocumentTypeImpl.call_replaceWith(instance, nodes);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_remove(instance: *runtime.Instance) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        return try DocumentTypeImpl.call_remove(instance);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_after(instance: *runtime.Instance, nodes: []const mixins.ParentNode.NodeOrString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try DocumentTypeImpl.call_after(instance, nodes);
    }

};
