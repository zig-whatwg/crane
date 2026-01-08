//! Generated from: wasm-js-api.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ExceptionImpl = @import("impls").Exception;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const ExceptionOptions = @import("dictionaries").ExceptionOptions;
const Tag = @import("Tag.zig").Tag;
const DOMString = @import("typedefs").DOMString;

pub const Exception = struct {
    pub const Meta = struct {
        pub const name = "Exception";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "LegacyNamespace", .value = .{ .identifier = "WebAssembly" } },
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker", "Worklet" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
            .Worklet = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "stack", "get_stack", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getArg", "call_getArg", 1 },
            .{ "is", "call_is", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getArg",
            "is",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "stack", "get_stack", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            stack: union(enum) {
                DOMString: runtime.DOMString,
                @"undefined": void,
            } = undefined,
            _internal: ?*ExceptionImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_stack = &get_stack,

        .call_getArg = &call_getArg,
        .call_is = &call_is,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ExceptionImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return ExceptionImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ExceptionImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, exceptionTag: *runtime.Instance, payload: runtime.JSValue, options: webidl.Opt(ExceptionOptions)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try ExceptionImpl.call_constructor(ctx, exceptionTag, payload, options);
    }

    pub fn get_stack(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try ExceptionImpl.get_stack(instance);
    }

    pub fn call_getArg(instance: *runtime.Instance, index: u32) anyerror!runtime.JSValue {
        // [EnforceRange] on index
        if (!runtime.isInRange(u32, index)) return error.TypeError;
        
        return try ExceptionImpl.call_getArg(instance, index);
    }

    pub fn call_is(instance: *runtime.Instance, exceptionTag: *runtime.Instance) anyerror!bool {
        
        return try ExceptionImpl.call_is(instance, exceptionTag);
    }

};
