//! HTML 8.6.2: Sanitizer's script-facing configuration operations.
//! Algorithms and owned configuration storage live in html.sanitizer.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const dictionaries = @import("dictionaries");
const webidl = @import("webidl");
const model = @import("html").sanitizer;

pub const State = interfaces.Sanitizer.State;
pub const ImplError = error{ OutOfMemory, TypeError, InvalidStateError };

pub const InternalState = struct {
    configuration: model.Config,
    // Result dictionaries outlive the native call: the binding converts them
    // after returning and after it has freed the converted arguments.
    result_arena: std.heap.ArenaAllocator,
};

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.result_arena.deinit();
        internal.configuration.deinit();
        instance.ctx.allocator.destroy(internal);
        state.own._internal = null;
    }
}

/// Constructor steps 1–2 and "configure": canonicalize, validate, retain.
pub fn call_constructor(ctx: runtime.Context, configuration: webidl.Opt(runtime.JSValue)) !*runtime.Instance {
    const input = configuration.getOrDefault(runtime.JSValue.fromStringRef("default"));
    var config = try model.Config.fromJS(ctx.allocator, ctx, input, true, false);
    errdefer config.deinit();
    const internal = try ctx.allocator.create(InternalState);
    errdefer ctx.allocator.destroy(internal);
    const instance = try interfaces.Sanitizer.init(ctx.allocator, ctx);
    internal.* = .{ .configuration = config, .result_arena = .init(ctx.allocator) };
    instance.getState(State).own._internal = internal;
    return instance;
}

fn stateOf(instance: *runtime.Instance) !*InternalState {
    return instance.getState(State).own._internal orelse error.InvalidStateError;
}

pub fn call_get(instance: *runtime.Instance) anyerror!dictionaries.SanitizerConfig {
    const internal = try stateOf(instance);
    _ = internal.result_arena.reset(.free_all);
    return toDictionary(try internal.configuration.toData(internal.result_arena.allocator()), internal.result_arena.allocator());
}

pub fn call_allowElement(instance: *runtime.Instance, element: typedefs.SanitizerElementWithAttributes) anyerror!bool {
    var arena = std.heap.ArenaAllocator.init(instance.ctx.allocator);
    defer arena.deinit();
    return (try stateOf(instance)).configuration.apply(.{ .allow_element = try toElement(arena.allocator(), element) });
}

pub fn call_removeElement(instance: *runtime.Instance, element: typedefs.SanitizerElement) anyerror!bool {
    return (try stateOf(instance)).configuration.apply(.{ .remove_element = toName(element, true) });
}

pub fn call_replaceElementWithChildren(instance: *runtime.Instance, element: typedefs.SanitizerElement) anyerror!bool {
    return (try stateOf(instance)).configuration.apply(.{ .replace_element = toName(element, true) });
}

pub fn call_allowAttribute(instance: *runtime.Instance, attribute: typedefs.SanitizerAttribute) anyerror!bool {
    return (try stateOf(instance)).configuration.apply(.{ .allow_attribute = toName(attribute, false) });
}

pub fn call_removeAttribute(instance: *runtime.Instance, attribute: typedefs.SanitizerAttribute) anyerror!bool {
    return (try stateOf(instance)).configuration.apply(.{ .remove_attribute = toName(attribute, false) });
}

pub fn call_allowProcessingInstruction(instance: *runtime.Instance, pi: typedefs.SanitizerPI) anyerror!bool {
    return (try stateOf(instance)).configuration.apply(.{ .allow_pi = piString(pi) });
}

pub fn call_removeProcessingInstruction(instance: *runtime.Instance, pi: typedefs.SanitizerPI) anyerror!bool {
    return (try stateOf(instance)).configuration.apply(.{ .remove_pi = piString(pi) });
}

pub fn call_setComments(instance: *runtime.Instance, allow: bool) anyerror!bool {
    return (try stateOf(instance)).configuration.apply(.{ .comments = allow });
}

pub fn call_setDataAttributes(instance: *runtime.Instance, allow: bool) anyerror!bool {
    return (try stateOf(instance)).configuration.apply(.{ .data_attributes = allow });
}

pub fn call_setJavascriptURLs(instance: *runtime.Instance, allow: bool) anyerror!bool {
    return (try stateOf(instance)).configuration.apply(.{ .javascript_urls = allow });
}

pub fn call_removeUnsafe(instance: *runtime.Instance) anyerror!bool {
    return (try stateOf(instance)).configuration.apply(.remove_unsafe);
}

// The binding owns these inputs for the whole call. The model copies every
// borrowed string before retaining it; only temporary lists need an arena.
fn namespace(value: ?runtime.DOMString) ?[]const u8 {
    const string = value orelse return null;
    return if (string.isEmpty()) null else string.asSlice();
}

fn toName(input: anytype, comptime element: bool) model.Name {
    if (input == .domstring) return .{
        .local = input.domstring.asSlice(),
        .namespace = if (element) model.html_namespace else null,
    };
    const dictionary = if (element) input.sanitizer_element_namespace else input.sanitizer_attribute_namespace;
    return .{
        .local = dictionary.name.asSlice(),
        .namespace = if (element)
            (if (dictionary.namespace.was_passed) namespace(dictionary.namespace.value) else model.html_namespace)
        else
            namespace(dictionary.namespace),
    };
}

fn toNames(allocator: std.mem.Allocator, input: ?[]const typedefs.SanitizerAttribute) !?[]model.Name {
    const items = input orelse return null;
    const output = try allocator.alloc(model.Name, items.len);
    for (items, output) |item, *name| name.* = toName(item, false);
    return output;
}

fn toElement(allocator: std.mem.Allocator, input: typedefs.SanitizerElementWithAttributes) !model.Element {
    return switch (input) {
        .domstring => |string| .{ .name = .{ .local = string.asSlice(), .namespace = model.html_namespace } },
        .sanitizer_element_namespace_with_attributes => |dictionary| .{
            .name = toName(typedefs.SanitizerElement{ .sanitizer_element_namespace = dictionary.base }, true),
            .attributes = try toNames(allocator, dictionary.attributes),
            .remove_attributes = try toNames(allocator, dictionary.removeAttributes),
        },
    };
}

fn piString(input: typedefs.SanitizerPI) []const u8 {
    return switch (input) {
        .domstring => |string| string.asSlice(),
        .sanitizer_processing_instruction => |dictionary| dictionary.target.asSlice(),
    };
}

fn exportNames(allocator: std.mem.Allocator, input: ?[]model.Name, comptime element: bool) !?[]const (if (element) typedefs.SanitizerElement else typedefs.SanitizerAttribute) {
    const names = input orelse return null;
    const output = try allocator.alloc(if (element) typedefs.SanitizerElement else typedefs.SanitizerAttribute, names.len);
    for (names, output) |name, *item| {
        const local = runtime.DOMString.initInterned(name.local);
        const ns: ?runtime.DOMString = if (name.namespace) |value| runtime.DOMString.initInterned(value) else null;
        if (element) item.* = .{ .sanitizer_element_namespace = .{ .name = local, .namespace = .passed(ns) } } else item.* = .{ .sanitizer_attribute_namespace = .{ .name = local, .namespace = ns } };
    }
    return output;
}

fn exportPIs(allocator: std.mem.Allocator, input: ?[][]const u8) !?[]const typedefs.SanitizerPI {
    const targets = input orelse return null;
    const output = try allocator.alloc(typedefs.SanitizerPI, targets.len);
    for (targets, output) |target, *item| item.* = .{ .sanitizer_processing_instruction = .{ .target = runtime.DOMString.initInterned(target) } };
    return output;
}

fn toDictionary(data: model.Data, allocator: std.mem.Allocator) !dictionaries.SanitizerConfig {
    var result = dictionaries.SanitizerConfig{
        .attributes = try exportNames(allocator, data.attributes, false),
        .removeAttributes = try exportNames(allocator, data.remove_attributes, false),
        .removeElements = try exportNames(allocator, data.remove_elements, true),
        .replaceWithChildrenElements = try exportNames(allocator, data.replace_elements, true),
        .processingInstructions = try exportPIs(allocator, data.processing_instructions),
        .removeProcessingInstructions = try exportPIs(allocator, data.remove_processing_instructions),
        .comments = data.comments,
        .dataAttributes = data.data_attributes,
        .javascriptURLs = data.javascript_urls,
    };
    if (data.elements) |elements| {
        const output = try allocator.alloc(typedefs.SanitizerElementWithAttributes, elements.len);
        for (elements, output) |element, *item| item.* = .{ .sanitizer_element_namespace_with_attributes = .{
            .base = .{ .name = runtime.DOMString.initInterned(element.name.local), .namespace = .passed(if (element.name.namespace) |ns| runtime.DOMString.initInterned(ns) else null) },
            .attributes = try exportNames(allocator, element.attributes, false),
            .removeAttributes = try exportNames(allocator, element.remove_attributes, false),
        } };
        result.elements = output;
    }
    return result;
}
