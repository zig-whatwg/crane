//! Implementation for the AudioWorkletProcessor interface (Web Audio API
//! 1.32.4). A processor is constructed only by an AudioWorkletNode's
//! construction, which renders audio - the host media backend's (the user's
//! 2026-10-08 ruling) - so no processor construction data is ever pending.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const AudioWorkletProcessor = interfaces.AudioWorkletProcessor;

pub const State = AudioWorkletProcessor.State;

pub const InternalState = struct {};

/// The constructor (1.32.4.1): step 2 looks up the pending processor
/// construction data, and step 3 throws a TypeError when there is none -
/// always, here: nothing constructs a processor for an AudioWorkletNode.
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    _ = ctx;
    return error.TypeError;
}

/// Getter for port: the processor's end of its node's port (not modelled).
pub fn get_port(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}
