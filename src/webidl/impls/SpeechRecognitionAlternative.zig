//! Implementation for SpeechRecognitionAlternative interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const SpeechRecognitionAlternative = @import("interfaces").SpeechRecognitionAlternative;

pub const State = SpeechRecognitionAlternative.State;

pub const ImplError = error{
    NotImplemented,
};

/// Initialize instance
pub fn init(instance: *runtime.Instance) void {
    _ = instance;
    // TODO: Initialize your instance state here
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    _ = instance;
    // TODO: Clean up your instance resources here
}

/// Getter for transcript
pub fn get_transcript(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for confidence
pub fn get_confidence(instance: *runtime.Instance) ImplError!f32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

