//! Generated from: intersection-observer.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const IntersectionObserverImpl = @import("impls").IntersectionObserver;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Document = @import("Document.zig").Document;
const Element = @import("Element.zig").Element;
const IntersectionObserverCallback = @import("callbacks").IntersectionObserverCallback;
const IntersectionObserverInit = @import("dictionaries").IntersectionObserverInit;
const IntersectionObserverEntry = @import("IntersectionObserverEntry.zig").IntersectionObserverEntry;
const DOMString = @import("typedefs").DOMString;

pub const IntersectionObserver = struct {
    pub const Meta = struct {
        pub const name = "IntersectionObserver";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "root", "get_root", null },
            .{ "rootMargin", "get_rootMargin", null },
            .{ "scrollMargin", "get_scrollMargin", null },
            .{ "thresholds", "get_thresholds", null },
            .{ "delay", "get_delay", null },
            .{ "trackVisibility", "get_trackVisibility", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "observe", "call_observe", 1 },
            .{ "unobserve", "call_unobserve", 1 },
            .{ "disconnect", "call_disconnect", 0 },
            .{ "takeRecords", "call_takeRecords", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "observe",
            "unobserve",
            "disconnect",
            "takeRecords",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "root", "get_root", null },
            .{ "rootMargin", "get_rootMargin", null },
            .{ "scrollMargin", "get_scrollMargin", null },
            .{ "thresholds", "get_thresholds", null },
            .{ "delay", "get_delay", null },
            .{ "trackVisibility", "get_trackVisibility", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
        };
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            root: ?union(enum) {
                Element: Element,
                Document: Document,
            } = null,
            rootMargin: typedefs.DOMString = undefined,
            scrollMargin: typedefs.DOMString = undefined,
            thresholds: runtime.JSValue = undefined,
            delay: i32 = undefined,
            trackVisibility: bool = undefined,
            _internal: ?*IntersectionObserverImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_delay = &get_delay,
        .get_root = &get_root,
        .get_rootMargin = &get_rootMargin,
        .get_scrollMargin = &get_scrollMargin,
        .get_thresholds = &get_thresholds,
        .get_trackVisibility = &get_trackVisibility,

        .call_disconnect = &call_disconnect,
        .call_observe = &call_observe,
        .call_takeRecords = &call_takeRecords,
        .call_unobserve = &call_unobserve,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return IntersectionObserverImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return IntersectionObserverImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        IntersectionObserverImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, callback: IntersectionObserverCallback, options: webidl.Opt(IntersectionObserverInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try IntersectionObserverImpl.call_constructor(ctx, callback, options);
    }

    pub fn get_root(instance: *runtime.Instance) anyerror!?runtime.JSValue {
        return try IntersectionObserverImpl.get_root(instance);
    }

    pub fn get_rootMargin(instance: *runtime.Instance) anyerror!DOMString {
        return try IntersectionObserverImpl.get_rootMargin(instance);
    }

    pub fn get_scrollMargin(instance: *runtime.Instance) anyerror!DOMString {
        return try IntersectionObserverImpl.get_scrollMargin(instance);
    }

    pub fn get_thresholds(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try IntersectionObserverImpl.get_thresholds(instance);
    }

    pub fn get_delay(instance: *runtime.Instance) anyerror!i32 {
        return try IntersectionObserverImpl.get_delay(instance);
    }

    pub fn get_trackVisibility(instance: *runtime.Instance) anyerror!bool {
        return try IntersectionObserverImpl.get_trackVisibility(instance);
    }

    pub fn call_unobserve(instance: *runtime.Instance, target: *runtime.Instance) anyerror!void {
        
        return try IntersectionObserverImpl.call_unobserve(instance, target);
    }

    pub fn call_observe(instance: *runtime.Instance, target: *runtime.Instance) anyerror!void {
        
        return try IntersectionObserverImpl.call_observe(instance, target);
    }

    pub fn call_disconnect(instance: *runtime.Instance) anyerror!void {
        return try IntersectionObserverImpl.call_disconnect(instance);
    }

    pub fn call_takeRecords(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try IntersectionObserverImpl.call_takeRecords(instance);
    }

};
