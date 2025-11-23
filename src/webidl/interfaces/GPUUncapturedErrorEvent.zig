//! Generated from: webgpu.idl
//! Generated at: 2025-11-23T16:59:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GPUUncapturedErrorEventImpl = @import("impls").GPUUncapturedErrorEvent;
const Event = @import("interfaces").Event;
const DOMString = @import("typedefs").DOMString;
const EventTarget = @import("interfaces").EventTarget;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const GPUUncapturedErrorEventInit = @import("dictionaries").GPUUncapturedErrorEventInit;
const GPUError = @import("interfaces").GPUError;

pub const GPUUncapturedErrorEvent = struct {
    pub const Meta = struct {
        pub const name = "GPUUncapturedErrorEvent";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Event;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "error", "get_error", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
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
            @"error": GPUError = undefined,
            cached_error: ?GPUError = null,
            _internal: ?*GPUUncapturedErrorEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_error = &get_error,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return GPUUncapturedErrorEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GPUUncapturedErrorEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, gpuUncapturedErrorEventInitDict: GPUUncapturedErrorEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try GPUUncapturedErrorEventImpl.call_constructor(allocator, ctx, @"type", gpuUncapturedErrorEventInitDict);
    }

    /// Extended attributes: [SameObject]
    pub fn get_error(instance: *runtime.Instance) anyerror!GPUError {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_error) |cached| {
            return cached;
        }
        const value = try GPUUncapturedErrorEventImpl.get_error(instance);
        state.own.cached_error = value;
        return value;
    }

};
