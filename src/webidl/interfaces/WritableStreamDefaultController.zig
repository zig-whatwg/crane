//! Generated from: streams.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const WritableStreamDefaultControllerImpl = @import("impls").WritableStreamDefaultController;
const mixins = @import("mixins");
const AbortSignal = @import("interfaces").AbortSignal;

pub const WritableStreamDefaultController = struct {
    pub const Meta = struct {
        pub const name = "WritableStreamDefaultController";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "signal", "get_signal", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "error", "call_error", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "error",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "signal", "get_signal", null },
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
            signal: *runtime.Instance = undefined,
            _internal: ?*WritableStreamDefaultControllerImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_signal = &get_signal,

        .call_error = &call_error,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return WritableStreamDefaultControllerImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return WritableStreamDefaultControllerImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WritableStreamDefaultControllerImpl.deinit(instance);
    }

    pub fn get_signal(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WritableStreamDefaultControllerImpl.get_signal(instance);
    }

    pub fn call_error(instance: *runtime.Instance, e: webidl.Opt(runtime.JSValue)) anyerror!void {
        
        return try WritableStreamDefaultControllerImpl.call_error(instance, e);
    }

};
