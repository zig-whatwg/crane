//! Generated from: xhr.idl
//! Generated at: 2025-11-28T19:51:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ProgressEventImpl = @import("impls").ProgressEvent;
const mixins = @import("mixins");
const Event = @import("interfaces").Event;
const EventTarget = @import("interfaces").EventTarget;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const ProgressEventInit = @import("dictionaries").ProgressEventInit;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const ProgressEvent = struct {
    pub const Meta = struct {
        pub const name = "ProgressEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Event;
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
            .{ "lengthComputable", "get_lengthComputable", null },
            .{ "loaded", "get_loaded", null },
            .{ "total", "get_total", null },
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
            .{ "lengthComputable", "get_lengthComputable", null },
            .{ "loaded", "get_loaded", null },
            .{ "total", "get_total", null },
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
            lengthComputable: bool = undefined,
            loaded: f64 = undefined,
            total: f64 = undefined,
            _internal: ?*ProgressEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_lengthComputable = &get_lengthComputable,
        .get_loaded = &get_loaded,
        .get_total = &get_total,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ProgressEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ProgressEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: webidl.Opt(ProgressEventInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try ProgressEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict.value);
    }

    pub fn get_lengthComputable(instance: *runtime.Instance) anyerror!bool {
        return try ProgressEventImpl.get_lengthComputable(instance);
    }

    pub fn get_loaded(instance: *runtime.Instance) anyerror!f64 {
        return try ProgressEventImpl.get_loaded(instance);
    }

    pub fn get_total(instance: *runtime.Instance) anyerror!f64 {
        return try ProgressEventImpl.get_total(instance);
    }

};
