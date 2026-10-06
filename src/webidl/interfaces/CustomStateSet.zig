//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CustomStateSetImpl = @import("impls").CustomStateSet;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DOMString = @import("typedefs").DOMString;

pub const CustomStateSet = struct {
    pub const Meta = struct {
        pub const name = "CustomStateSet";
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
            .{ "size", "get_size", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "has", "call_has", 1 },
            .{ "forEach", "call_forEach", 1 },
            .{ "add", "call_add", 1 },
            .{ "delete", "call_delete", 1 },
            .{ "clear", "call_clear", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "has",
            "forEach",
            "add",
            "delete",
            "clear",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "size", "get_size", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            size: u32 = undefined,
            _internal: ?*CustomStateSetImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_size = &get_size,

        .call_add = &call_add,
        .call_clear = &call_clear,
        .call_delete = &call_delete,
        .call_forEach = &call_forEach,
        .call_has = &call_has,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates, Meta.name, State);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CustomStateSetImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return CustomStateSetImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CustomStateSetImpl.deinit(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "CustomStateSet")) {
            if (comptime @hasDecl(impls.CustomStateSet, "installHooks")) impls.CustomStateSet.installHooks();
        }
    }

    pub fn get_size(instance: *runtime.Instance) anyerror!u32 {
        return try CustomStateSetImpl.get_size(instance);
    }

    pub fn call_has(instance: *runtime.Instance, value: DOMString) anyerror!bool {
        return try CustomStateSetImpl.call_has(instance, value);
    }

    pub fn call_delete(instance: *runtime.Instance, value: DOMString) anyerror!bool {
        return try CustomStateSetImpl.call_delete(instance, value);
    }

    pub fn call_clear(instance: *runtime.Instance) anyerror!void {
        return try CustomStateSetImpl.call_clear(instance);
    }

    pub fn call_forEach(instance: *runtime.Instance, callback: runtime.JSValue, thisArg: webidl.Opt(runtime.JSValue)) anyerror!void {
        return try CustomStateSetImpl.call_forEach(instance, callback, thisArg);
    }

    pub fn call_add(instance: *runtime.Instance, value: DOMString) anyerror!*runtime.Instance {
        return try CustomStateSetImpl.call_add(instance, value);
    }
};
