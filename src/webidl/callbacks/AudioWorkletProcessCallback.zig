//! WebIDL callback: AudioWorkletProcessCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");

pub const AudioWorkletProcessCallback = *const fn (inputs: *const anyopaque, outputs: *const anyopaque, parameters: v8.JSValue) bool;
