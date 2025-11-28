//! Generated from: html.idl
//! Generated at: 2025-11-28T19:51:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const HTMLOrSVGElementImpl = @import("impls").HTMLOrSVGElement;
const mixins = @import("mixins");
const DOMStringMap = @import("interfaces").DOMStringMap;
const DOMString = @import("typedefs").DOMString;
const FocusOptions = @import("dictionaries").FocusOptions;

pub const HTMLOrSVGElement = struct {
    pub const Meta = struct {
        pub const name = "HTMLOrSVGElement";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "dataset", "get_dataset", null },
            .{ "nonce", "get_nonce", "set_nonce" },
            .{ "autofocus", "get_autofocus", "set_autofocus" },
            .{ "tabIndex", "get_tabIndex", "set_tabIndex" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "focus", "call_focus", 0 },
            .{ "blur", "call_blur", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "focus",
            "blur",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "nonce", "get_nonce", "set_nonce" },
            .{ "autofocus", "get_autofocus", "set_autofocus" },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
            .{ "dataset", "get_dataset", null },
            .{ "tabIndex", "get_tabIndex", "set_tabIndex" },
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            dataset: *runtime.Instance = undefined,
            nonce: runtime.DOMString = undefined,
            autofocus: bool = undefined,
            tabIndex: i32 = undefined,
            cached_dataset: ?*runtime.Instance = null,
            _internal: ?*HTMLOrSVGElementImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_autofocus = &get_autofocus,
        .get_dataset = &get_dataset,
        .get_nonce = &get_nonce,
        .get_tabIndex = &get_tabIndex,

        .set_autofocus = &set_autofocus,
        .set_nonce = &set_nonce,
        .set_tabIndex = &set_tabIndex,

        .call_blur = &call_blur,
        .call_focus = &call_focus,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return HTMLOrSVGElementImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HTMLOrSVGElementImpl.deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_dataset(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_dataset) |cached| {
            return cached;
        }
        const value = try HTMLOrSVGElementImpl.get_dataset(instance);
        state.own.cached_dataset = value;
        return value;
    }

    pub fn get_nonce(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLOrSVGElementImpl.get_nonce(instance);
    }

    pub fn set_nonce(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try HTMLOrSVGElementImpl.set_nonce(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_autofocus(instance: *runtime.Instance) anyerror!bool {
        return try HTMLOrSVGElementImpl.get_autofocus(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_autofocus(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLOrSVGElementImpl.set_autofocus(instance, value);
    }

    /// Extended attributes: [CEReactions], [ReflectSetter]
    pub fn get_tabIndex(instance: *runtime.Instance) anyerror!i32 {
        return try HTMLOrSVGElementImpl.get_tabIndex(instance);
    }

    /// Extended attributes: [CEReactions], [ReflectSetter]
    pub fn set_tabIndex(instance: *runtime.Instance, value: i32) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLOrSVGElementImpl.set_tabIndex(instance, value);
    }

    pub fn call_blur(instance: *runtime.Instance) anyerror!void {
        return try HTMLOrSVGElementImpl.call_blur(instance);
    }

    pub fn call_focus(instance: *runtime.Instance, options: webidl.Opt(FocusOptions)) anyerror!void {
        
        return try HTMLOrSVGElementImpl.call_focus(instance, options.value);
    }

};
