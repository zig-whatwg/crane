//! Generated from: dom.idl
//! Generated at: 2025-11-28T18:02:24Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ProcessingInstructionImpl = @import("impls").ProcessingInstruction;
const CharacterData = @import("interfaces").CharacterData;
const LinkStyle = @import("interfaces").LinkStyle;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const CSSStyleSheet = @import("interfaces").CSSStyleSheet;
const Document = @import("interfaces").Document;
const Node = @import("interfaces").Node;
const NodeList = @import("interfaces").NodeList;
const USVString = @import("interfaces").USVString;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const Element = @import("interfaces").Element;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const StyleSheet = @import("interfaces").StyleSheet;
const EventListener = @import("interfaces").EventListener;
const GetRootNodeOptions = @import("dictionaries").GetRootNodeOptions;
const DOMString = @import("typedefs").DOMString;

pub const ProcessingInstruction = struct {
    pub const Meta = struct {
        pub const name = "ProcessingInstruction";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *CharacterData;
        pub const MixinTypes = &.{
            LinkStyle,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "target", "get_target", null },
            .{ "sheet", "get_sheet", null },
            .{ "sheet", "get_sheet", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
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
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "target", "get_target", null },
            .{ "sheet", "get_sheet", null },
            .{ "sheet", "get_sheet", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            target: runtime.DOMString = undefined,
            sheet: ?*runtime.Instance = null,
            _internal: ?*ProcessingInstructionImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_sheet = &get_sheet,
        .get_target = &get_target,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ProcessingInstructionImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ProcessingInstructionImpl.deinit(instance);
    }

    pub fn get_target(instance: *runtime.Instance) anyerror!DOMString {
        return try ProcessingInstructionImpl.get_target(instance);
    }

    pub fn get_sheet(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try ProcessingInstructionImpl.get_sheet(instance);
    }

};
