//! Implementation for the AudioWorklet interface (Web Audio API 1.32): a
//! Worklet whose worklet global scope type is AudioWorkletGlobalScope and
//! whose destination type is "audioworklet". Its Worklet state is Worklet's
//! (the construction chain runs Worklet's part); the port belongs to the
//! audio rendering the host media backend supplies, which Crane does not run.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const AudioWorklet = interfaces.AudioWorklet;

pub const State = AudioWorklet.State;

/// No state beyond Worklet's (the generated State names it).
pub const InternalState = struct {};

/// Getter for port: the MessagePort entangled with the
/// AudioWorkletGlobalScope's - made with the rendering thread, which the
/// host media backend supplies (not modelled).
pub fn get_port(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}
