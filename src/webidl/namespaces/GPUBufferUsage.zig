//! WebIDL namespace: GPUBufferUsage
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const GPUBufferUsage_impl = @import("impls").GPUBufferUsage;

pub const GPUBufferUsage = struct {
    pub const Meta = struct {
        pub const name = "GPUBufferUsage";
        pub const is_namespace = true;
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "SecureContext" },
        };
        pub const BaseType = null;
        pub const MixinTypes = &.{};

        /// Method binding hints (JS name, Zig function name, WebIDL length)
        pub const methods = .{};

        pub const has_constructor = false;
        pub const properties = .{};
    };

    pub const State = struct {};
};
