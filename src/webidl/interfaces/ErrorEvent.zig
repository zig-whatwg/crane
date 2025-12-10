//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ErrorEventImpl = @import("impls").ErrorEvent;
const mixins = @import("mixins");
const Event = @import("interfaces").Event;
const EventTarget = @import("interfaces").EventTarget;
const ErrorEventInit = @import("dictionaries").ErrorEventInit;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const USVString = @import("interfaces").USVString;
const DOMString = @import("typedefs").DOMString;

pub const ErrorEvent = struct {
    pub const Meta = struct {
        pub const name = "ErrorEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = Event.State;
        pub const ParentInterface = Event;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "message", "get_message", null },
            .{ "filename", "get_filename", null },
            .{ "lineno", "get_lineno", null },
            .{ "colno", "get_colno", null },
            .{ "error", "get_error", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "composedPath",
            "stopPropagation",
            "stopImmediatePropagation",
            "preventDefault",
            "initEvent",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "message", "get_message", null },
            .{ "filename", "get_filename", null },
            .{ "lineno", "get_lineno", null },
            .{ "colno", "get_colno", null },
            .{ "error", "get_error", null },
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
            message: runtime.DOMString = undefined,
            filename: runtime.USVString = undefined,
            lineno: u32 = undefined,
            colno: u32 = undefined,
            @"error": runtime.JSValue = undefined,
            _internal: ?*ErrorEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_colno = &get_colno,
        .get_error = &get_error,
        .get_filename = &get_filename,
        .get_lineno = &get_lineno,
        .get_message = &get_message,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ErrorEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return ErrorEventImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ErrorEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, @"type": DOMString, eventInitDict: webidl.Opt(ErrorEventInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try ErrorEventImpl.call_constructor(ctx, @"type", eventInitDict);
    }

    pub fn get_message(instance: *runtime.Instance) anyerror!DOMString {
        return try ErrorEventImpl.get_message(instance);
    }

    pub fn get_filename(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try ErrorEventImpl.get_filename(instance);
    }

    pub fn get_lineno(instance: *runtime.Instance) anyerror!u32 {
        return try ErrorEventImpl.get_lineno(instance);
    }

    pub fn get_colno(instance: *runtime.Instance) anyerror!u32 {
        return try ErrorEventImpl.get_colno(instance);
    }

    pub fn get_error(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try ErrorEventImpl.get_error(instance);
    }

};
