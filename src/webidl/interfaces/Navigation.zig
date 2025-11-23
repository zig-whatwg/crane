//! Generated from: html.idl
//! Generated at: 2025-11-23T01:22:14Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NavigationImpl = @import("impls").Navigation;
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const NavigationActivation = @import("interfaces").NavigationActivation;
const NavigationTransition = @import("interfaces").NavigationTransition;
const NavigationHistoryEntry = @import("interfaces").NavigationHistoryEntry;
const USVString = @import("interfaces").USVString;
const NavigationUpdateCurrentEntryOptions = @import("dictionaries").NavigationUpdateCurrentEntryOptions;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const NavigationResult = @import("dictionaries").NavigationResult;
const NavigationOptions = @import("dictionaries").NavigationOptions;
const NavigationNavigateOptions = @import("dictionaries").NavigationNavigateOptions;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const NavigationReloadOptions = @import("dictionaries").NavigationReloadOptions;
const DOMString = @import("typedefs").DOMString;
const EventHandler = @import("typedefs").EventHandler;

pub const Navigation = struct {
    pub const Meta = struct {
        pub const name = "Navigation";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "currentEntry", "get_currentEntry", null },
            .{ "transition", "get_transition", null },
            .{ "activation", "get_activation", null },
            .{ "canGoBack", "get_canGoBack", null },
            .{ "canGoForward", "get_canGoForward", null },
            .{ "onnavigate", "get_onnavigate", "set_onnavigate" },
            .{ "onnavigatesuccess", "get_onnavigatesuccess", "set_onnavigatesuccess" },
            .{ "onnavigateerror", "get_onnavigateerror", "set_onnavigateerror" },
            .{ "oncurrententrychange", "get_oncurrententrychange", "set_oncurrententrychange" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "entries", "call_entries", 0 },
            .{ "updateCurrentEntry", "call_updateCurrentEntry", 1 },
            .{ "navigate", "call_navigate", 1 },
            .{ "reload", "call_reload", 0 },
            .{ "traverseTo", "call_traverseTo", 1 },
            .{ "back", "call_back", 0 },
            .{ "forward", "call_forward", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "entries",
            "updateCurrentEntry",
            "navigate",
            "reload",
            "traverseTo",
            "back",
            "forward",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "currentEntry", "get_currentEntry", null },
            .{ "transition", "get_transition", null },
            .{ "activation", "get_activation", null },
            .{ "canGoBack", "get_canGoBack", null },
            .{ "canGoForward", "get_canGoForward", null },
            .{ "onnavigate", "get_onnavigate", "set_onnavigate" },
            .{ "onnavigatesuccess", "get_onnavigatesuccess", "set_onnavigatesuccess" },
            .{ "onnavigateerror", "get_onnavigateerror", "set_onnavigateerror" },
            .{ "oncurrententrychange", "get_oncurrententrychange", "set_oncurrententrychange" },
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
            currentEntry: ?NavigationHistoryEntry = null,
            transition: ?NavigationTransition = null,
            activation: ?NavigationActivation = null,
            canGoBack: bool = undefined,
            canGoForward: bool = undefined,
            onnavigate: EventHandler = undefined,
            onnavigatesuccess: EventHandler = undefined,
            onnavigateerror: EventHandler = undefined,
            oncurrententrychange: EventHandler = undefined,
        },
    );

    const delegates = .{

        .get_activation = &get_activation,
        .get_canGoBack = &get_canGoBack,
        .get_canGoForward = &get_canGoForward,
        .get_currentEntry = &get_currentEntry,
        .get_oncurrententrychange = &get_oncurrententrychange,
        .get_onnavigate = &get_onnavigate,
        .get_onnavigateerror = &get_onnavigateerror,
        .get_onnavigatesuccess = &get_onnavigatesuccess,
        .get_transition = &get_transition,

        .set_oncurrententrychange = &set_oncurrententrychange,
        .set_onnavigate = &set_onnavigate,
        .set_onnavigateerror = &set_onnavigateerror,
        .set_onnavigatesuccess = &set_onnavigatesuccess,

        .call_back = &call_back,
        .call_entries = &call_entries,
        .call_forward = &call_forward,
        .call_navigate = &call_navigate,
        .call_reload = &call_reload,
        .call_traverseTo = &call_traverseTo,
        .call_updateCurrentEntry = &call_updateCurrentEntry,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return NavigationImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NavigationImpl.deinit(instance);
    }

    pub fn get_currentEntry(instance: *runtime.Instance) anyerror!NavigationHistoryEntry {
        return try NavigationImpl.get_currentEntry(instance);
    }

    pub fn get_transition(instance: *runtime.Instance) anyerror!NavigationTransition {
        return try NavigationImpl.get_transition(instance);
    }

    pub fn get_activation(instance: *runtime.Instance) anyerror!NavigationActivation {
        return try NavigationImpl.get_activation(instance);
    }

    pub fn get_canGoBack(instance: *runtime.Instance) anyerror!bool {
        return try NavigationImpl.get_canGoBack(instance);
    }

    pub fn get_canGoForward(instance: *runtime.Instance) anyerror!bool {
        return try NavigationImpl.get_canGoForward(instance);
    }

    pub fn get_onnavigate(instance: *runtime.Instance) anyerror!EventHandler {
        return try NavigationImpl.get_onnavigate(instance);
    }

    pub fn set_onnavigate(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try NavigationImpl.set_onnavigate(instance, value);
    }

    pub fn get_onnavigatesuccess(instance: *runtime.Instance) anyerror!EventHandler {
        return try NavigationImpl.get_onnavigatesuccess(instance);
    }

    pub fn set_onnavigatesuccess(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try NavigationImpl.set_onnavigatesuccess(instance, value);
    }

    pub fn get_onnavigateerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try NavigationImpl.get_onnavigateerror(instance);
    }

    pub fn set_onnavigateerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try NavigationImpl.set_onnavigateerror(instance, value);
    }

    pub fn get_oncurrententrychange(instance: *runtime.Instance) anyerror!EventHandler {
        return try NavigationImpl.get_oncurrententrychange(instance);
    }

    pub fn set_oncurrententrychange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try NavigationImpl.set_oncurrententrychange(instance, value);
    }

    pub fn call_reload(instance: *runtime.Instance, options: NavigationReloadOptions) anyerror!NavigationResult {
        
        return try NavigationImpl.call_reload(instance, options);
    }

    pub fn call_back(instance: *runtime.Instance, options: NavigationOptions) anyerror!NavigationResult {
        
        return try NavigationImpl.call_back(instance, options);
    }

    pub fn call_entries(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try NavigationImpl.call_entries(instance);
    }

    pub fn call_navigate(instance: *runtime.Instance, url: runtime.USVString, options: NavigationNavigateOptions) anyerror!NavigationResult {
        
        return try NavigationImpl.call_navigate(instance, url, options);
    }

    pub fn call_traverseTo(instance: *runtime.Instance, key: DOMString, options: NavigationOptions) anyerror!NavigationResult {
        
        return try NavigationImpl.call_traverseTo(instance, key, options);
    }

    pub fn call_forward(instance: *runtime.Instance, options: NavigationOptions) anyerror!NavigationResult {
        
        return try NavigationImpl.call_forward(instance, options);
    }

    pub fn call_updateCurrentEntry(instance: *runtime.Instance, options: NavigationUpdateCurrentEntryOptions) anyerror!void {
        
        return try NavigationImpl.call_updateCurrentEntry(instance, options);
    }

};
