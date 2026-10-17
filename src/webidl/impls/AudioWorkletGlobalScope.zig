//! Implementation for the AudioWorkletGlobalScope interface (Web Audio API
//! 1.32.3): the audio worklet's global scope, whose registerProcessor()
//! records a processor definition. Audio rendering is the host media
//! backend's (the user's 2026-10-08 ruling), and Crane runs none, so no
//! processor is constructed and the rendering-thread members (currentFrame,
//! currentTime, sampleRate, renderQuantumSize, port) are not modelled.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const callbacks = @import("callbacks");
const engine = @import("engine");
const html = @import("html");
const AudioWorkletGlobalScope = interfaces.AudioWorkletGlobalScope;
const worklet_host = html.worklet_host;

pub const State = AudioWorkletGlobalScope.State;

/// One entry of the node name to processor constructor map, less the
/// constructor, which nothing constructs: the AudioParamDescriptors'
/// names, kept for the node name to parameter descriptor map.
const ProcessorDefinition = struct {
    parameter_names: [][]u8,
};

pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// The node name to processor constructor map.
    definitions: worklet_host.Definitions(ProcessorDefinition) = .{},
};

fn freeDefinition(allocator: std.mem.Allocator, definition: *ProcessorDefinition) void {
    worklet_host.freeStrings(allocator, definition.parameter_names);
}

fn internalOf(instance: *runtime.Instance) !*InternalState {
    const state = instance.getState(State);
    if (state.own._internal) |internal| return internal;
    const allocator = instance.ctx.allocator;
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator };
    state.own._internal = internal;
    return internal;
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    internal.definitions.deinit(internal.allocator, freeDefinition);
    internal.allocator.destroy(internal);
    state.own._internal = null;
}

pub fn get_currentFrame(instance: *runtime.Instance) anyerror!u64 {
    _ = instance;
    return error.NotImplemented;
}

pub fn get_currentTime(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return error.NotImplemented;
}

pub fn get_sampleRate(instance: *runtime.Instance) anyerror!f32 {
    _ = instance;
    return error.NotImplemented;
}

pub fn get_renderQuantumSize(instance: *runtime.Instance) anyerror!u32 {
    _ = instance;
    return error.NotImplemented;
}

pub fn get_port(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// registerProcessor(name, processorCtor) - Web Audio API 1.32.3.2.
pub fn call_registerProcessor(instance: *runtime.Instance, name: runtime.DOMString, processorCtor: callbacks.AudioWorkletProcessorConstructor) anyerror!void {
    const constructor = engine.takeCallbackFunction(@ptrCast(processorCtor));
    defer constructor.release();
    const realm = instance.ctx;
    const ctor = constructor.function.value;
    const name_slice = name.asSlice();

    // Step 1: an empty name throws a NotSupportedError.
    if (name_slice.len == 0) return error.NotSupportedError;
    // Step 2: a name already in the map throws a NotSupportedError.
    const internal = try internalOf(instance);
    const allocator = internal.allocator;
    if (internal.definitions.contains(name_slice)) return error.NotSupportedError;
    // Steps 3-5: a constructor whose prototype is an Object.
    const prototype = try worklet_host.classPrototype(realm, ctor);
    prototype.release();
    // Steps 6-7: parameterDescriptors, as sequence<AudioParamDescriptor>.
    const parameter_names = try parameterDescriptors(realm, ctor, allocator);
    errdefer worklet_host.freeStrings(allocator, parameter_names);
    // Step 8: name -> processorCtor. Step 9 appends the descriptors to the
    // BaseAudioContext's node name to parameter descriptor map, for
    // AudioWorkletNode's construction, which renders audio: not modelled.
    try internal.definitions.put(allocator, name_slice, .{ .parameter_names = parameter_names });
}

/// Steps 6-7: Get(processorCtor, "parameterDescriptors") converted to
/// sequence<AudioParamDescriptor> when it is not undefined, each checked
/// (7.3.1: a repeated name is a NotSupportedError; 7.3.6: minValue <=
/// defaultValue <= maxValue, or an InvalidStateError). The names, OWNED.
fn parameterDescriptors(realm: runtime.Context, ctor: runtime.JSValue, allocator: std.mem.Allocator) ![][]u8 {
    const value = try engine.getProperty(realm, ctor, "parameterDescriptors");
    defer value.release();
    var names: std.ArrayListUnmanaged([]u8) = .empty;
    errdefer {
        for (names.items) |item| allocator.free(item);
        names.deinit(allocator);
    }
    if (engine.typeOf(realm, value.value) == .undefined) return names.toOwnedSlice(allocator);
    if (engine.typeOf(realm, value.value) != .object) return error.TypeError;
    const descriptors = try engine.convertToSequenceOfObjects(realm, value.value, allocator);
    defer {
        for (descriptors) |descriptor| descriptor.release();
        allocator.free(descriptors);
    }
    // 7.1: the whole sequence is converted before any descriptor is checked.
    const parsed = try allocator.alloc(ParsedDescriptor, descriptors.len);
    defer allocator.free(parsed);
    var converted: usize = 0;
    defer for (parsed[0..converted]) |descriptor| allocator.free(descriptor.name);
    for (descriptors) |descriptor| {
        parsed[converted] = try audioParamDescriptor(realm, descriptor.value, allocator);
        converted += 1;
    }
    // 7.3.
    for (parsed[0..converted]) |descriptor| {
        for (names.items) |seen| {
            if (std.mem.eql(u8, seen, descriptor.name)) return error.NotSupportedError;
        }
        if (!(descriptor.min_value <= descriptor.default_value and descriptor.default_value <= descriptor.max_value)) return error.InvalidStateError;
        try names.append(allocator, try allocator.dupe(u8, descriptor.name));
    }
    return names.toOwnedSlice(allocator);
}

const ParsedDescriptor = struct { name: []u8, default_value: f32, min_value: f32, max_value: f32 };

/// The dictionary AudioParamDescriptor (Web Audio API 1.32.4) from
/// `object`, its members read in lexicographic order (WebIDL 3.2.18):
/// automationRate ("a-rate" or "k-rate"), defaultValue (0), maxValue and
/// minValue (the most positive and negative float), name (required).
fn audioParamDescriptor(realm: runtime.Context, object: runtime.JSValue, allocator: std.mem.Allocator) !ParsedDescriptor {
    {
        const rate = try engine.getProperty(realm, object, "automationRate");
        defer rate.release();
        if (engine.typeOf(realm, rate.value) != .undefined) {
            const string = try engine.convertToDOMString(realm, rate.value, allocator);
            defer allocator.free(string);
            if (!std.mem.eql(u8, string, "a-rate") and !std.mem.eql(u8, string, "k-rate")) return error.TypeError;
        }
    }
    const default_value = try floatMember(realm, object, "defaultValue", 0);
    const max_value = try floatMember(realm, object, "maxValue", std.math.floatMax(f32));
    const min_value = try floatMember(realm, object, "minValue", -std.math.floatMax(f32));
    const name = try engine.getProperty(realm, object, "name");
    defer name.release();
    if (engine.typeOf(realm, name.value) == .undefined) return error.TypeError;
    return .{
        .name = try engine.convertToDOMString(realm, name.value, allocator),
        .default_value = default_value,
        .min_value = min_value,
        .max_value = max_value,
    };
}

/// A `float` dictionary member (WebIDL 3.2.6): `default` when undefined; a
/// TypeError for a value that is not finite, or out of float's range.
fn floatMember(realm: runtime.Context, object: runtime.JSValue, member: []const u8, default: f32) !f32 {
    const value = try engine.getProperty(realm, object, member);
    defer value.release();
    if (engine.typeOf(realm, value.value) == .undefined) return default;
    const number = try engine.convertToUnrestrictedDouble(realm, value.value);
    if (!std.math.isFinite(number)) return error.TypeError;
    const narrowed: f32 = @floatCast(number);
    if (!std.math.isFinite(narrowed)) return error.TypeError;
    return narrowed;
}
