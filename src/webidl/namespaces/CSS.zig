//! WebIDL namespace: CSS
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const CSS_impl = @import("impls").CSS;

pub const CSS = struct {
    pub const Meta = struct {
        pub const name = "CSS";
        pub const is_namespace = true;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        
        /// Method binding hints for V8Interface (JS name, Zig function name)
        pub const methods = .{
        };
        
        pub const has_constructor = false;
        pub const properties = .{};
    };

    pub const State = struct {};

    pub const animationWorklet: *const anyopaque = undefined;

};
