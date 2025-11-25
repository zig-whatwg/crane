//! Implementation for TextEncoderCommon interface mixin
//!
//! WHATWG Encoding Standard § 5.2.1
//! https://encoding.spec.whatwg.org/#interface-mixin-textencodercommon
//!
//! This mixin defines the readonly encoding attribute shared by TextEncoder
//! and TextEncoderStream. The encoding is always "utf-8" for these encoders.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const TextEncoderCommon = interfaces.TextEncoderCommon;

pub const State = TextEncoderCommon.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
/// For the mixin, this is empty - the main interface (TextEncoder/TextEncoderStream)
/// stores the actual encoder state.
pub const InternalState = struct {};

/// Initialize instance (creates the instance)
/// Note: Mixins are typically not instantiated directly - this is provided for completeness.
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    runtime.Instance.deinit(instance);
}

/// Getter for encoding
/// Returns the encoding name (always "utf-8" for TextEncoder/TextEncoderStream)
/// Spec: https://encoding.spec.whatwg.org/#dom-textencodercommon-encoding
pub fn get_encoding(instance: *runtime.Instance) ImplError!runtime.DOMString {
    const state = instance.getState(State);
    return state.own.encoding;
}
