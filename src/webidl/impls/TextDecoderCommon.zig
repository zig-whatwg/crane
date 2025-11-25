//! Implementation for TextDecoderCommon interface mixin
//!
//! WHATWG Encoding Standard § 5.1.1
//! https://encoding.spec.whatwg.org/#interface-mixin-textdecodercommon
//!
//! This mixin defines readonly attributes shared by TextDecoder and TextDecoderStream.
//! The attributes describe the decoder's configuration and cannot be changed after construction.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const TextDecoderCommon = interfaces.TextDecoderCommon;

pub const State = TextDecoderCommon.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
/// For the mixin, this is empty - the main interface (TextDecoder/TextDecoderStream)
/// stores the actual decoder state.
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
/// Returns the encoding name (lowercase ASCII, e.g., "utf-8", "windows-1252")
/// Spec: https://encoding.spec.whatwg.org/#dom-textdecodercommon-encoding
pub fn get_encoding(instance: *runtime.Instance) ImplError!runtime.DOMString {
    const state = instance.getState(State);
    return state.own.encoding;
}

/// Getter for fatal
/// Returns true if decoder throws on errors, false if it uses replacement character
/// Spec: https://encoding.spec.whatwg.org/#dom-textdecodercommon-fatal
pub fn get_fatal(instance: *runtime.Instance) ImplError!bool {
    const state = instance.getState(State);
    return state.own.fatal;
}

/// Getter for ignoreBOM
/// Returns true if BOM is kept in output, false if BOM is stripped
/// Spec: https://encoding.spec.whatwg.org/#dom-textdecodercommon-ignorebom
pub fn get_ignoreBOM(instance: *runtime.Instance) ImplError!bool {
    const state = instance.getState(State);
    return state.own.ignoreBOM;
}
