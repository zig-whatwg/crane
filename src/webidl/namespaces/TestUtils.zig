//! WebIDL namespace: TestUtils
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const TestUtils_impl = @import("impls").TestUtils;

pub const TestUtils = struct {
    pub const Meta = struct {
        pub const name = "TestUtils";
        pub const is_namespace = true;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        
        /// Method binding hints for V8Interface (JS name, Zig function name)
        pub const methods = .{
            .{ "gc", "call_gc" },
        };
        
        pub const has_constructor = false;
        pub const properties = .{};
    };

    pub const State = struct {};

    pub fn call_gc(ctx: runtime.Context) *const anyopaque {
        return TestUtils_impl.call_gc(ctx);
    }

};
