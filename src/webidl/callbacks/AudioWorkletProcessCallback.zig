//! WebIDL callback: AudioWorkletProcessCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const AudioWorkletProcessCallback = *const fn (inputs: runtime.JSValue, outputs: runtime.JSValue, parameters: runtime.JSValue) bool;
