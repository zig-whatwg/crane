//! Implementation for HTMLSlotElement interface
//!
//! Spec: https://html.spec.whatwg.org/multipage/scripting.html#the-slot-element
//!
//! A slot element is a DOM slot (DOM 4.2.2.1): it has a name, assigned
//! nodes and - HTML - manually assigned nodes. Their state is a
//! `dom.slot_helpers.SlotState`, kept here and handed to the slot algorithms
//! (dom.shadow_dom_algorithms) through `dom.slot_helpers`.

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const dom = @import("dom");
const HTMLSlotElement = interfaces.HTMLSlotElement;

pub const State = HTMLSlotElement.State;

pub const ImplError = error{
    NotImplemented,
};

/// The slot's DOM state: its name, assigned nodes and manually assigned
/// nodes.
pub const InternalState = struct {
    slot: dom.slot_helpers.SlotState,

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{ .slot = dom.slot_helpers.SlotState.init(allocator) };
    }

    pub fn deinit(self: *InternalState) void {
        self.slot.deinit();
    }
};

const utils = @import("webidl").utils;
const Registry = utils.InstanceRegistry(InternalState);

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Registry.get(instance);
}

/// The hooks this type owns (src/dom), installed once, at process start, by
/// crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    // The slot algorithms read a slot's state through `dom.slot_helpers`.
    dom.slot_helpers.install(.{ .slot_state = &slotStateOf });
    // DOM 4.2.2.1: "Use these attribute change steps to update a slot's
    // name" - for an HTML slot element, the steps Element runs for its type.
    dom.attribute_change_steps.install("slot", &attributeChangeSteps);
}

/// `dom.slot_helpers`: the slot's state.
fn slotStateOf(instance: *runtime.Instance) ?*dom.slot_helpers.SlotState {
    const internal = getInternal(instance) orelse return null;
    return &internal.slot;
}

/// DOM 4.2.2.1: the attribute change steps that update a slot's name, "if
/// element is a slot, localName is name, and namespace is null".
fn attributeChangeSteps(
    element: *runtime.Instance,
    local_name: []const u8,
    old_value: ?[]const u8,
    value: ?[]const u8,
    namespace: ?[]const u8,
) void {
    if (namespace != null or !std.mem.eql(u8, local_name, "name")) return;
    dom.shadow_dom_algorithms.slotNameChanged(element, old_value, value);
}

/// Initialize instance (creates the instance)
/// Chains to parent class: HTMLElement -> Element -> Node -> EventTarget
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    // Chain to parent class (HTMLElement), through its interface.
    const instance = try interfaces.HTMLElement.initWithState(allocator, StateType, vtable, ctx);
    errdefer interfaces.HTMLElement.deinit(instance);

    // The registry owns this block, so `Registry.remove` returns it to the
    // arena.
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    const internal = try Registry.createIn(instance, ArenaAllocator.get());
    internal.* = InternalState.init(allocator);
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // A slot whose slotchange is still pending leaves the agent's signal
    // slots, so that notify cannot reach a freed slot.
    dom.mutation_observer_algorithms.forgetSlot(instance);
    if (Registry.get(instance)) |internal| internal.deinit();
    Registry.remove(instance);
    // Chain to parent class, through its interface.
    interfaces.HTMLElement.deinit(instance);
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(ctx.allocator, State, &HTMLSlotElement.vtable, ctx);
    errdefer deinit(instance);

    // TODO: Implement constructor logic with parameters

    return instance;
}

/// The nodes as a sequence<Node> (or sequence<Element>) for script, made in
/// the current realm.
fn sequenceOf(instance: *runtime.Instance, nodes: []const *runtime.Instance) !runtime.JSValue {
    const realm = engine.currentRealm() orelse instance.ctx;
    const array = try engine.createSequenceOfPlatformObjects(realm, nodes);
    return array.take();
}

/// HTML assignedNodes(options): "If options["flatten"] is false, then return
/// this's assigned nodes. Return the result of finding flattened slottables
/// with this."
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#dom-slot-assignednodes
pub fn call_assignedNodes(instance: *runtime.Instance, options: webidl.Opt(dictionaries.AssignedNodesOptions)) anyerror!runtime.JSValue {
    const flatten = if (options.was_passed) options.value.flatten orelse false else false;
    const allocator = instance.ctx.allocator;
    const nodes = try dom.shadow_dom_algorithms.assignedNodes(allocator, instance, flatten, false);
    defer allocator.free(nodes);
    return sequenceOf(instance, nodes);
}

/// HTML assignedElements(options): assignedNodes(options), "filtered to
/// contain only Element nodes".
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#dom-slot-assignedelements
pub fn call_assignedElements(instance: *runtime.Instance, options: webidl.Opt(dictionaries.AssignedNodesOptions)) anyerror!runtime.JSValue {
    const flatten = if (options.was_passed) options.value.flatten orelse false else false;
    const allocator = instance.ctx.allocator;
    const nodes = try dom.shadow_dom_algorithms.assignedNodes(allocator, instance, flatten, true);
    defer allocator.free(nodes);
    return sequenceOf(instance, nodes);
}

/// HTML assign(...nodes): set this's manually assigned nodes.
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#dom-slot-assign
pub fn call_assign(instance: *runtime.Instance, nodes: []const runtime.JSValue) anyerror!void {
    const allocator = instance.ctx.allocator;
    // WebIDL: each argument converts to `(Element or Text)` - a platform
    // object implementing Element or Text, else a TypeError (3.2.24).
    const converted = try allocator.alloc(*runtime.Instance, nodes.len);
    defer allocator.free(converted);
    const realm = engine.currentRealm() orelse instance.ctx;
    for (nodes, converted) |value, *out| {
        const node = engine.convertToPlatformObject(realm, value) orelse return error.TypeError;
        if (node.stateAs(interfaces.Element.State) == null and node.stateAs(interfaces.Text.State) == null) return error.TypeError;
        out.* = node;
    }
    try dom.shadow_dom_algorithms.assign(allocator, instance, converted);
}
