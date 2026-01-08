//! Implementation for AudioWorkletGlobalScope interface
//! Per Web Audio API spec: https://webaudio.github.io/web-audio-api/#AudioWorkletGlobalScope

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const AudioWorkletGlobalScope = interfaces.AudioWorkletGlobalScope;

pub const State = AudioWorkletGlobalScope.State;

pub const ImplError = error{
    NotImplemented,
    ProcessorAlreadyRegistered,
    InvalidProcessorName,
};

/// Registered processor info
pub const RegisteredProcessor = struct {
    name: []const u8,
    constructor: callbacks.AudioWorkletProcessorConstructor,
};

/// Internal state for AudioWorkletGlobalScope
/// Stores audio rendering parameters and registered processors
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// Current sample frame being rendered
    current_frame: u64,
    /// Sample rate in Hz (e.g., 44100, 48000)
    sample_rate: f32,
    /// Render quantum size (typically 128 samples)
    render_quantum_size: u32,
    /// MessagePort for communication with main thread
    port: ?*runtime.Instance,
    /// Registered AudioWorkletProcessor constructors
    registered_processors: std.StringHashMap(callbacks.AudioWorkletProcessorConstructor),

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
            .current_frame = 0,
            .sample_rate = 48000.0, // Default sample rate
            .render_quantum_size = 128, // Web Audio API default
            .port = null,
            .registered_processors = std.StringHashMap(callbacks.AudioWorkletProcessorConstructor).init(allocator),
        };
    }

    pub fn deinit(self: *InternalState) void {
        // Free registered processor name keys
        var it = self.registered_processors.keyIterator();
        while (it.next()) |key| {
            self.allocator.free(key.*);
        }
        self.registered_processors.deinit();
    }

    /// Get current time in seconds based on frame count and sample rate
    pub fn getCurrentTime(self: *const InternalState) f64 {
        return @as(f64, @floatFromInt(self.current_frame)) / @as(f64, self.sample_rate);
    }

    /// Advance the frame counter by one render quantum
    pub fn advanceFrame(self: *InternalState) void {
        self.current_frame += self.render_quantum_size;
    }
};

/// Global registry mapping instances to their internal state
/// Uses a simple hashmap since runtime.ImplDataRegistry doesn't exist
var internal_state_map: ?std.AutoHashMap(*runtime.Instance, *InternalState) = null;
var map_allocator: ?std.mem.Allocator = null;

fn getRegistry(allocator: std.mem.Allocator) *std.AutoHashMap(*runtime.Instance, *InternalState) {
    if (internal_state_map == null) {
        internal_state_map = std.AutoHashMap(*runtime.Instance, *InternalState).init(allocator);
        map_allocator = allocator;
    }
    return &internal_state_map.?;
}

fn getInternalState(instance: *runtime.Instance) ?*InternalState {
    if (internal_state_map) |*map| {
        return map.get(instance);
    }
    return null;
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer instance.deinit();

    // Initialize internal state
    const internal = try allocator.create(InternalState);
    internal.* = InternalState.init(allocator);
    errdefer {
        internal.deinit();
        allocator.destroy(internal);
    }

    const registry = getRegistry(allocator);
    try registry.put(instance, internal);

    return instance;
}

/// Initialize with specific audio parameters
pub fn initWithAudioParams(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
    sample_rate: f32,
    render_quantum_size: u32,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer instance.deinit();

    // Initialize internal state with audio parameters
    const internal = try allocator.create(InternalState);
    internal.* = InternalState.init(allocator);
    internal.sample_rate = sample_rate;
    internal.render_quantum_size = render_quantum_size;
    errdefer {
        internal.deinit();
        allocator.destroy(internal);
    }

    const registry = getRegistry(allocator);
    try registry.put(instance, internal);

    return instance;
}

/// Set the MessagePort for communication
pub fn setPort(instance: *runtime.Instance, port: *runtime.Instance) void {
    if (getInternalState(instance)) |internal| {
        internal.port = port;
    }
}

/// Update current frame (called by audio rendering thread)
pub fn updateCurrentFrame(instance: *runtime.Instance, frame: u64) void {
    if (getInternalState(instance)) |internal| {
        internal.current_frame = frame;
    }
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    if (internal_state_map) |*map| {
        if (map.fetchRemove(instance)) |kv| {
            kv.value.deinit();
            if (map_allocator) |alloc| {
                alloc.destroy(kv.value);
            }
        }
    }
}

/// Getter for currentFrame
/// Returns the current sample frame being processed
pub fn get_currentFrame(instance: *runtime.Instance) anyerror!u64 {
    if (getInternalState(instance)) |internal| {
        return internal.current_frame;
    }
    return 0;
}

/// Getter for currentTime
/// Returns the current audio context time in seconds
pub fn get_currentTime(instance: *runtime.Instance) anyerror!f64 {
    if (getInternalState(instance)) |internal| {
        return internal.getCurrentTime();
    }
    return 0.0;
}

/// Getter for sampleRate
/// Returns the sample rate in Hz
pub fn get_sampleRate(instance: *runtime.Instance) anyerror!f32 {
    if (getInternalState(instance)) |internal| {
        return internal.sample_rate;
    }
    return 48000.0; // Default sample rate
}

/// Getter for renderQuantumSize
/// Returns the render quantum size (typically 128 samples)
pub fn get_renderQuantumSize(instance: *runtime.Instance) anyerror!u32 {
    if (getInternalState(instance)) |internal| {
        return internal.render_quantum_size;
    }
    return 128; // Web Audio API default
}

/// Getter for port
/// Returns the MessagePort for communication with the main thread
pub fn get_port(instance: *runtime.Instance) anyerror!*runtime.Instance {
    if (getInternalState(instance)) |internal| {
        if (internal.port) |port| {
            return port;
        }
    }
    return error.NotImplemented; // Port not yet set
}

/// Operation: registerProcessor
/// Registers an AudioWorkletProcessor class for use in AudioWorkletNode
/// Per spec: https://webaudio.github.io/web-audio-api/#dom-audioworkletglobalscope-registerprocessor
pub fn call_registerProcessor(instance: *runtime.Instance, name: runtime.DOMString, processorCtor: callbacks.AudioWorkletProcessorConstructor) anyerror!void {
    const internal = getInternalState(instance) orelse return error.NotImplemented;
    const allocator = internal.allocator;

    // Get the processor name as a string
    const name_slice = name.asSlice();
    if (name_slice.len == 0) return error.InvalidProcessorName;

    // Check if processor with this name is already registered
    if (internal.registered_processors.contains(name_slice)) {
        return error.ProcessorAlreadyRegistered;
    }

    // Copy the name for storage
    const name_copy = try allocator.dupe(u8, name_slice);
    errdefer allocator.free(name_copy);

    // Register the processor constructor
    try internal.registered_processors.put(name_copy, processorCtor);
}

/// Get a registered processor constructor by name
pub fn getRegisteredProcessor(instance: *runtime.Instance, name: []const u8) ?callbacks.AudioWorkletProcessorConstructor {
    if (getInternalState(instance)) |internal| {
        return internal.registered_processors.get(name);
    }
    return null;
}

/// Check if a processor is registered
pub fn isProcessorRegistered(instance: *runtime.Instance, name: []const u8) bool {
    if (getInternalState(instance)) |internal| {
        return internal.registered_processors.contains(name);
    }
    return false;
}
