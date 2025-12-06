//! Generated from: webgpu.idl
//! Generated at: 2025-12-05T20:30:47Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const GPUPipelineErrorImpl = @import("impls").GPUPipelineError;
const mixins = @import("mixins");
const DOMException = @import("interfaces").DOMException;
const GPUPipelineErrorReason = @import("enums").GPUPipelineErrorReason;
const GPUPipelineErrorInit = @import("dictionaries").GPUPipelineErrorInit;
const DOMString = @import("typedefs").DOMString;

pub const GPUPipelineError = struct {
    pub const Meta = struct {
        pub const name = "GPUPipelineError";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = DOMException.State;
        pub const ParentInterface = DOMException;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "SecureContext" },
            .{ .name = "Serializable" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "reason", "get_reason", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "reason", "get_reason", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            reason: GPUPipelineErrorReason = undefined,
            _internal: ?*GPUPipelineErrorImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_reason = &get_reason,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return GPUPipelineErrorImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GPUPipelineErrorImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, message: webidl.Opt(DOMString), options: GPUPipelineErrorInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try GPUPipelineErrorImpl.call_constructor(allocator, ctx, message, options);
    }

    pub fn get_reason(instance: *runtime.Instance) anyerror!GPUPipelineErrorReason {
        return try GPUPipelineErrorImpl.get_reason(instance);
    }
};
