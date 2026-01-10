//! Generated from: dom.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CharacterDataImpl = @import("impls").CharacterData;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Node = @import("Node.zig").Node;
const NonDocumentTypeChildNode = @import("mixins").NonDocumentTypeChildNode;
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

pub const CharacterData = struct {
    pub const Meta = struct {
        pub const name = "CharacterData";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = Node.State;
        pub const ParentInterface = Node;
        pub const MixinTypes = &.{
            NonDocumentTypeChildNode,
            ChildNode,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "data", "get_data", "set_data" },
            .{ "length", "get_length", null },
            .{ "previousElementSibling", "get_previousElementSibling", null },
            .{ "nextElementSibling", "get_nextElementSibling", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "substringData", "call_substringData", 2 },
            .{ "appendData", "call_appendData", 1 },
            .{ "insertData", "call_insertData", 2 },
            .{ "deleteData", "call_deleteData", 2 },
            .{ "replaceData", "call_replaceData", 3 },
            .{ "before", "call_before", 0 },
            .{ "after", "call_after", 0 },
            .{ "replaceWith", "call_replaceWith", 0 },
            .{ "remove", "call_remove", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "substringData",
            "appendData",
            "insertData",
            "deleteData",
            "replaceData",
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
            .{ "data", "get_data", "set_data" },
            .{ "length", "get_length", null },
            .{ "previousElementSibling", "get_previousElementSibling", null },
            .{ "nextElementSibling", "get_nextElementSibling", null },
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
            data: typedefs.DOMString = undefined,
            length: u32 = undefined,
            previousElementSibling: ?*runtime.Instance = null,
            nextElementSibling: ?*runtime.Instance = null,
            _internal: ?*CharacterDataImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_data = &get_data,
        .get_length = &get_length,
        .get_nextElementSibling = &get_nextElementSibling,
        .get_previousElementSibling = &get_previousElementSibling,

        .set_data = &set_data,

        .call_after = &call_after,
        .call_appendData = &call_appendData,
        .call_before = &call_before,
        .call_deleteData = &call_deleteData,
        .call_insertData = &call_insertData,
        .call_remove = &call_remove,
        .call_replaceData = &call_replaceData,
        .call_replaceWith = &call_replaceWith,
        .call_substringData = &call_substringData,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CharacterDataImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return CharacterDataImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CharacterDataImpl.deinit(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_data(instance: *runtime.Instance) anyerror!DOMString {
        return try CharacterDataImpl.get_data(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_data(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CharacterDataImpl.set_data(instance, value);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try CharacterDataImpl.get_length(instance);
    }

    pub fn get_previousElementSibling(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try CharacterDataImpl.get_previousElementSibling(instance);
    }

    pub fn get_nextElementSibling(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try CharacterDataImpl.get_nextElementSibling(instance);
    }

    pub fn call_replaceData(instance: *runtime.Instance, offset: u32, count: u32, data: DOMString) anyerror!void {
        
        return try CharacterDataImpl.call_replaceData(instance, offset, count, data);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_before(instance: *runtime.Instance, nodes: []const mixins.ParentNode.NodeOrString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try CharacterDataImpl.call_before(instance, nodes);
    }

    pub fn call_deleteData(instance: *runtime.Instance, offset: u32, count: u32) anyerror!void {
        
        return try CharacterDataImpl.call_deleteData(instance, offset, count);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_remove(instance: *runtime.Instance) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        return try CharacterDataImpl.call_remove(instance);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_after(instance: *runtime.Instance, nodes: []const mixins.ParentNode.NodeOrString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try CharacterDataImpl.call_after(instance, nodes);
    }

    pub fn call_appendData(instance: *runtime.Instance, data: DOMString) anyerror!void {
        
        return try CharacterDataImpl.call_appendData(instance, data);
    }

    pub fn call_substringData(instance: *runtime.Instance, offset: u32, count: u32) anyerror!DOMString {
        
        return try CharacterDataImpl.call_substringData(instance, offset, count);
    }

    pub fn call_insertData(instance: *runtime.Instance, offset: u32, data: DOMString) anyerror!void {
        
        return try CharacterDataImpl.call_insertData(instance, offset, data);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_replaceWith(instance: *runtime.Instance, nodes: []const mixins.ParentNode.NodeOrString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try CharacterDataImpl.call_replaceWith(instance, nodes);
    }

};
