//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ElementContentEditableImpl = @import("impls").ElementContentEditable;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DOMString = @import("typedefs").DOMString;

pub const ElementContentEditable = struct {
    pub const Meta = struct {
        pub const name = "ElementContentEditable";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "contentEditable", "get_contentEditable", "set_contentEditable" },
            .{ "enterKeyHint", "get_enterKeyHint", "set_enterKeyHint" },
            .{ "isContentEditable", "get_isContentEditable", null },
            .{ "inputMode", "get_inputMode", "set_inputMode" },
            .{ "virtualKeyboardPolicy", "get_virtualKeyboardPolicy", "set_virtualKeyboardPolicy" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "enterKeyHint", "get_enterKeyHint", "set_enterKeyHint" },
            .{ "inputMode", "get_inputMode", "set_inputMode" },
            .{ "virtualKeyboardPolicy", "get_virtualKeyboardPolicy", "set_virtualKeyboardPolicy" },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
            .{ "contentEditable", "get_contentEditable", "set_contentEditable" },
            .{ "isContentEditable", "get_isContentEditable", null },
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            contentEditable: typedefs.DOMString = undefined,
            enterKeyHint: typedefs.DOMString = undefined,
            isContentEditable: bool = undefined,
            inputMode: typedefs.DOMString = undefined,
            virtualKeyboardPolicy: typedefs.DOMString = undefined,
            _internal: ?*ElementContentEditableImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_contentEditable = &get_contentEditable,
        .get_enterKeyHint = &get_enterKeyHint,
        .get_inputMode = &get_inputMode,
        .get_isContentEditable = &get_isContentEditable,
        .get_virtualKeyboardPolicy = &get_virtualKeyboardPolicy,

        .set_contentEditable = &set_contentEditable,
        .set_enterKeyHint = &set_enterKeyHint,
        .set_inputMode = &set_inputMode,
        .set_virtualKeyboardPolicy = &set_virtualKeyboardPolicy,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ElementContentEditableImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return ElementContentEditableImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ElementContentEditableImpl.deinit(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_contentEditable(instance: *runtime.Instance) anyerror!DOMString {
        return try ElementContentEditableImpl.get_contentEditable(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_contentEditable(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementContentEditableImpl.set_contentEditable(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_enterKeyHint(instance: *runtime.Instance) anyerror!DOMString {
        return try ElementContentEditableImpl.get_enterKeyHint(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_enterKeyHint(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementContentEditableImpl.set_enterKeyHint(instance, value);
    }

    pub fn get_isContentEditable(instance: *runtime.Instance) anyerror!bool {
        return try ElementContentEditableImpl.get_isContentEditable(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_inputMode(instance: *runtime.Instance) anyerror!DOMString {
        return try ElementContentEditableImpl.get_inputMode(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_inputMode(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementContentEditableImpl.set_inputMode(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_virtualKeyboardPolicy(instance: *runtime.Instance) anyerror!DOMString {
        return try ElementContentEditableImpl.get_virtualKeyboardPolicy(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_virtualKeyboardPolicy(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementContentEditableImpl.set_virtualKeyboardPolicy(instance, value);
    }

};
