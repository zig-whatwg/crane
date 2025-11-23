//! Generated from: dom.idl
//! Generated at: 2025-11-23T20:06:13Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const AttrImpl = @import("impls").Attr;
const Node = @import("interfaces").Node;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const Document = @import("interfaces").Document;
const NodeList = @import("interfaces").NodeList;
const USVString = @import("interfaces").USVString;
const Event = @import("interfaces").Event;
const Observable = @import("interfaces").Observable;
const Element = @import("interfaces").Element;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const GetRootNodeOptions = @import("dictionaries").GetRootNodeOptions;
const DOMString = @import("typedefs").DOMString;

pub const Attr = struct {
    pub const Meta = struct {
        pub const name = "Attr";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Node;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "namespaceURI", "get_namespaceURI", null },
            .{ "prefix", "get_prefix", null },
            .{ "localName", "get_localName", null },
            .{ "name", "get_name", null },
            .{ "value", "get_value", "set_value" },
            .{ "ownerElement", "get_ownerElement", null },
            .{ "specified", "get_specified", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
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
            .{ "value", "get_value", "set_value" },
            .{ "ownerElement", "get_ownerElement", null },
            .{ "specified", "get_specified", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
            .{ "namespaceURI", "get_namespaceURI", null },
            .{ "prefix", "get_prefix", null },
            .{ "localName", "get_localName", null },
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            namespaceURI: ?runtime.DOMString = null,
            prefix: ?runtime.DOMString = null,
            localName: runtime.DOMString = undefined,
            name: runtime.DOMString = undefined,
            value: runtime.DOMString = undefined,
            ownerElement: ?*runtime.Instance = null,
            specified: bool = undefined,
            _internal: ?*AttrImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_localName = &get_localName,
        .get_name = &get_name,
        .get_namespaceURI = &get_namespaceURI,
        .get_ownerElement = &get_ownerElement,
        .get_prefix = &get_prefix,
        .get_specified = &get_specified,
        .get_value = &get_value,

        .set_value = &set_value,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return AttrImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        AttrImpl.deinit(instance);
    }

    pub fn get_namespaceURI(instance: *runtime.Instance) anyerror!DOMString {
        return try AttrImpl.get_namespaceURI(instance);
    }

    pub fn get_prefix(instance: *runtime.Instance) anyerror!DOMString {
        return try AttrImpl.get_prefix(instance);
    }

    pub fn get_localName(instance: *runtime.Instance) anyerror!DOMString {
        return try AttrImpl.get_localName(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try AttrImpl.get_name(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_value(instance: *runtime.Instance) anyerror!DOMString {
        return try AttrImpl.get_value(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_value(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try AttrImpl.set_value(instance, value);
    }

    pub fn get_ownerElement(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try AttrImpl.get_ownerElement(instance);
    }

    pub fn get_specified(instance: *runtime.Instance) anyerror!bool {
        return try AttrImpl.get_specified(instance);
    }

};
