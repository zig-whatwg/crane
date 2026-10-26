//! WebIDL namespace: GPUColorWrite
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const GPUColorWrite_impl = @import("impls").GPUColorWrite;

pub const GPUColorWrite = struct {
    pub const Meta = struct {
        pub const name = "GPUColorWrite";
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
