//! Generated from: css-regions.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NamedFlowImpl = @import("impls").NamedFlow;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("EventTarget.zig").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const Element = @import("Element.zig").Element;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const Event = @import("Event.zig").Event;
const CSSOMString = @import("typedefs").CSSOMString;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("EventListener.zig").EventListener;
const Node = @import("Node.zig").Node;
const DOMString = @import("typedefs").DOMString;
const Observable = @import("Observable.zig").Observable;

pub const NamedFlow = struct {
    pub const Meta = struct {
        pub const name = "NamedFlow";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "name", "get_name", null },
            .{ "overset", "get_overset", null },
            .{ "firstEmptyRegionIndex", "get_firstEmptyRegionIndex", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getRegions", "call_getRegions", 0 },
            .{ "getContent", "call_getContent", 0 },
            .{ "getRegionsByContent", "call_getRegionsByContent", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getRegions",
            "getContent",
            "getRegionsByContent",
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
            .{ "name", "get_name", null },
            .{ "overset", "get_overset", null },
            .{ "firstEmptyRegionIndex", "get_firstEmptyRegionIndex", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
        };
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            name: typedefs.CSSOMString = undefined,
            overset: bool = undefined,
            firstEmptyRegionIndex: i16 = undefined,
            _internal: ?*NamedFlowImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_firstEmptyRegionIndex = &get_firstEmptyRegionIndex,
        .get_name = &get_name,
        .get_overset = &get_overset,

        .call_getContent = &call_getContent,
        .call_getRegions = &call_getRegions,
        .call_getRegionsByContent = &call_getRegionsByContent,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return NamedFlowImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return NamedFlowImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NamedFlowImpl.deinit(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!CSSOMString {
        return try NamedFlowImpl.get_name(instance);
    }

    pub fn get_overset(instance: *runtime.Instance) anyerror!bool {
        return try NamedFlowImpl.get_overset(instance);
    }

    pub fn get_firstEmptyRegionIndex(instance: *runtime.Instance) anyerror!i16 {
        return try NamedFlowImpl.get_firstEmptyRegionIndex(instance);
    }

    pub fn call_getRegions(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try NamedFlowImpl.call_getRegions(instance);
    }

    pub fn call_getRegionsByContent(instance: *runtime.Instance, node: *runtime.Instance) anyerror!runtime.JSValue {
        
        return try NamedFlowImpl.call_getRegionsByContent(instance, node);
    }

    pub fn call_getContent(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try NamedFlowImpl.call_getContent(instance);
    }

};
