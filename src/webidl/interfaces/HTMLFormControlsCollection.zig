//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const HTMLFormControlsCollectionImpl = @import("impls").HTMLFormControlsCollection;
const mixins = @import("mixins");
const HTMLCollection = @import("interfaces").HTMLCollection;
const Element = @import("interfaces").Element;
const RadioNodeList = @import("interfaces").RadioNodeList;
const DOMString = @import("typedefs").DOMString;

pub const HTMLFormControlsCollection = struct {
    pub const Meta = struct {
        pub const name = "HTMLFormControlsCollection";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = HTMLCollection.State;
        pub const ParentInterface = HTMLCollection;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "namedItem", "call_namedItem", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "namedItem",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "item",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
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
            _internal: ?*HTMLFormControlsCollectionImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_namedItem = &call_namedItem,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return HTMLFormControlsCollectionImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return HTMLFormControlsCollectionImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HTMLFormControlsCollectionImpl.deinit(instance);
    }

    pub fn call_namedItem(instance: *runtime.Instance, name: DOMString) anyerror!?runtime.JSValue {
        
        return try HTMLFormControlsCollectionImpl.call_namedItem(instance, name);
    }

    /// Get supported property names for named property enumeration (Reflect.ownKeys, etc.)
    /// Per WebIDL spec §3.9.3, returns names in list order for proper enumeration
    pub fn getSupportedPropertyNames(instance: *runtime.Instance, allocator: std.mem.Allocator) ![]runtime.DOMString {
        return HTMLFormControlsCollectionImpl.getSupportedPropertyNames(instance, allocator);
    }

};
