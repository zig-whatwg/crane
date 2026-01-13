//! Generated from: content-index.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ContentIndexImpl = @import("impls").ContentIndex;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const ContentDescription = @import("dictionaries").ContentDescription;
const DOMString = @import("typedefs").DOMString;

pub const ContentIndex = struct {
    pub const Meta = struct {
        pub const name = "ContentIndex";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "add", "call_add", 1 },
            .{ "delete", "call_delete", 1 },
            .{ "getAll", "call_getAll", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "add",
            "delete",
            "getAll",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
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
            _internal: ?*ContentIndexImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_add = &call_add,
        .call_delete = &call_delete,
        .call_getAll = &call_getAll,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ContentIndexImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return ContentIndexImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ContentIndexImpl.deinit(instance);
    }

    pub fn call_delete(instance: *runtime.Instance, id: DOMString) anyerror!runtime.JSValue {
        
        return try ContentIndexImpl.call_delete(instance, id);
    }

    pub fn call_getAll(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try ContentIndexImpl.call_getAll(instance);
    }

    pub fn call_add(instance: *runtime.Instance, description: ContentDescription) anyerror!runtime.JSValue {
        
        return try ContentIndexImpl.call_add(instance, description);
    }

};
