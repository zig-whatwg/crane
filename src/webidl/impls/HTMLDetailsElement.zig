//! Implementation for HTMLDetailsElement interface
//!
//! Spec: HTML Standard § 4.11.1 The details element
//! https://html.spec.whatwg.org/multipage/interactive-elements.html#the-details-element
//!
//! `open` and `name` reflect their content attributes (the generated
//! interface does that). What is here is what the element does when they
//! change: the attribute change steps - the details notification task steps,
//! which fire `toggle`, and the details name group's exclusivity - and the
//! insertion steps, which keep a group exclusive as elements join a tree.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const engine = @import("engine");
const HTMLDetailsElement = interfaces.HTMLDetailsElement;

// Ancestors: a details element IS an HTMLElement, an Element, a Node and an
// EventTarget, and reaches their state through their impls.
const HTMLElementImpl = @import("HTMLElement.zig");
const ElementImpl = @import("Element.zig");
const NodeImpl = @import("Node.zig");
const EventTargetImpl = @import("EventTarget.zig");

// The hooks the element installs its steps into: the attribute change steps
// (DOM 4.9) and the insertion steps (DOM 4.2.3).
const dom_module = @import("dom");
const instance_bridge = dom_module.instance_bridge;
const NodeBase = dom_module.NodeBase;

const log = std.log.scoped(.details);

pub const State = HTMLDetailsElement.State;

pub const ImplError = error{
    NotImplemented,
};

/// The element's own state.
pub const InternalState = struct {
    /// HTML: the details toggle task tracker - the toggle task queued and not
    /// yet run, with the old state it carries; null when none is.
    toggle_task: ?*ToggleTask = null,
    /// Toggle tasks in the loop's queue, cancelled ones included; the element
    /// has pending activity while any waits.
    queued_toggle_tasks: u32 = 0,
    allocator: std.mem.Allocator,
};

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    dom_module.attribute_change_steps.install("details", &attributeChangeSteps);
    dom_module.mutation.registerInsertionStepsCallback(&insertionStepsCallback) catch |err| {
        log.warn("details insertion steps not registered: {}", .{err});
    };
}

/// Initialize instance: the chain to HTMLElement.
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try HTMLElementImpl.init(allocator, StateType, vtable, ctx);
    errdefer HTMLElementImpl.deinit(instance);
    // From the arena that holds the element's state, as every element's
    // internal state is: an element in a tree is freed with its tree, and
    // teardown does not always run `deinit` - a block from the context
    // allocator leaked once per parsed details element.
    const internal = try runtime.ArenaAllocator.get().create(InternalState);
    internal.* = .{ .allocator = allocator };
    instance.getState(StateType).own._internal = internal;
    return instance;
}

/// Deinitialize instance. A toggle task still queued finds the element gone
/// (its generation) and does nothing.
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        if (internal.toggle_task) |task| task.cancelled = true;
        if (runtime.ArenaAllocator.tryGet() catch null) |arena| arena.destroy(InternalState, internal);
        state.own._internal = null;
    }
    HTMLElementImpl.deinit(instance);
}

/// Constructor implementation
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &HTMLDetailsElement.vtable, ctx);
    errdefer deinit(instance);
    return instance;
}

// ============================================================================
// The attribute change and insertion steps
// ============================================================================

/// The attribute change steps for every details element, given element,
/// localName, oldValue, value and namespace.
fn attributeChangeSteps(
    element: *runtime.Instance,
    local_name: []const u8,
    old_value: ?[]const u8,
    value: ?[]const u8,
    namespace: ?[]const u8,
) void {
    // 1. If namespace is not null, then return.
    if (namespace != null) return;
    // An SVG or other element named "details" is not this element.
    if (getInternal(element) == null) return;

    // 2. If localName is name, then ensure details exclusivity by closing the
    // given element if needed given element.
    if (std.mem.eql(u8, local_name, "name")) {
        ensureExclusivityClosingGiven(element);
        return;
    }

    // 3. If localName is open, then:
    if (!std.mem.eql(u8, local_name, "open")) return;
    // 3.1. If one of oldValue or value is null and the other is not null, run
    // the details notification task steps: queue a details toggle event task
    // given element, "closed" and "open" when oldValue is null, and "open"
    // and "closed" otherwise.
    if ((old_value == null) != (value == null)) {
        if (old_value == null) {
            queueToggleEventTask(element, "closed", "open");
        } else {
            queueToggleEventTask(element, "open", "closed");
        }
    }
    // 3.2. If oldValue is null and value is not null, then ensure details
    // exclusivity by closing other elements if needed given element.
    if (old_value == null and value != null) ensureExclusivityClosingOthers(element);
}

/// The details element's HTML element insertion steps, given insertedNode:
/// ensure details exclusivity by closing the given element if needed. Called
/// for every node inserted; acts on details elements only.
fn insertionStepsCallback(node: *NodeBase) void {
    if (node.node_type != 1) return;
    const instance_ptr = instance_bridge.getInstance(node) orelse return;
    const instance: *runtime.Instance = @ptrCast(@alignCast(instance_ptr));
    // A details element is one whose state chain has this interface's (the
    // brand check). `node.node_name` cannot say: it is "" for every element
    // whose impl does not set it, and setting it (NodeImpl.setLocalName)
    // allocates a name some teardown paths never free.
    if (getInternal(instance) == null) return;
    ensureExclusivityClosingGiven(instance);
}

// ============================================================================
// The details name group
// ============================================================================

/// `element`'s name attribute (in no namespace), when present and not the
/// empty string. BORROWED: the attribute's value.
fn groupName(element: *runtime.Instance) ?[]const u8 {
    const name = (ElementImpl.call_getAttributeNS(element, null, runtime.DOMString.initInterned("name")) catch null) orelse return null;
    const slice = name.asSlice();
    return if (slice.len == 0) null else slice;
}

fn hasOpen(element: *runtime.Instance) bool {
    return ElementImpl.call_hasAttributeNS(element, null, runtime.DOMString.initInterned("open")) catch false;
}

fn removeOpen(element: *runtime.Instance) void {
    ElementImpl.call_removeAttributeNS(element, null, runtime.DOMString.initInterned("open")) catch |err| {
        log.warn("details open attribute not removed: {}", .{err});
    };
}

/// The next node after `node` in tree order within `root`'s tree, or null
/// past the last.
fn nextInTree(node: *runtime.Instance, root: *runtime.Instance) ?*runtime.Instance {
    if (NodeImpl.getFirstChild(node)) |child| return child;
    var current = node;
    while (current != root) {
        if (NodeImpl.getNextSibling(current)) |sibling| return sibling;
        current = NodeImpl.getParent(current) orelse return null;
    }
    return null;
}

/// The first element of `element`'s details name group, other than
/// `element`, whose open attribute is set - in tree order. The group: the
/// details elements in the same tree whose name attribute is not the empty
/// string and equals `element`'s. Null when `element` is in no group (no
/// name, or the empty one) or no other member is open.
fn openGroupMember(element: *runtime.Instance, name: []const u8) ?*runtime.Instance {
    const root = NodeImpl.call_getRootNode(element, webidl.Opt(dictionaries.GetRootNodeOptions).notPassed()) catch return null;
    var node: ?*runtime.Instance = root;
    while (node) |current| : (node = nextInTree(current, root)) {
        if (current == element) continue;
        if (getInternal(current) == null) continue;
        const other_name = groupName(current) orelse continue;
        if (!std.mem.eql(u8, other_name, name)) continue;
        if (hasOpen(current)) return current;
    }
    return null;
}

/// HTML "ensure details exclusivity by closing other elements if needed"
/// given element.
fn ensureExclusivityClosingOthers(element: *runtime.Instance) void {
    // 1. Assert: element has an open attribute.
    // 2. If element has no name attribute, or it is the empty string, return.
    const name = groupName(element) orelse return;
    // 3-4. For each other member of the group, in tree order: if its open
    // attribute is set - there is at most one - remove it, and break.
    const other = openGroupMember(element, name) orelse return;
    removeOpen(other);
}

/// HTML "ensure details exclusivity by closing the given element if needed"
/// given element.
fn ensureExclusivityClosingGiven(element: *runtime.Instance) void {
    // 1. If element does not have an open attribute, then return.
    if (!hasOpen(element)) return;
    // 2. If element has no name attribute, or it is the empty string, return.
    const name = groupName(element) orelse return;
    // 3-4. If any other member of the group is open, remove element's open
    // attribute.
    if (openGroupMember(element, name) != null) removeOpen(element);
}

// ============================================================================
// The toggle event
// ============================================================================

/// A queued details toggle event task: the element, and the states it fires
/// `toggle` with. `cancelled` is the spec's "remove the task from its task
/// queue" - a later toggle took its place, or the element went. A cancelled
/// task stays in the loop's queue and does nothing when it comes up.
const ToggleTask = struct {
    element: *runtime.Instance,
    generation: u64,
    old_state: []const u8,
    new_state: []const u8,
    cancelled: bool = false,
    allocator: std.mem.Allocator,

    fn run(data: ?*anyopaque) void {
        const self: *ToggleTask = @ptrCast(@alignCast(data orelse return));
        defer self.finish();
        if (self.cancelled or !self.elementIsLive()) return;
        // A realm retired by a navigation: its document is no longer fully
        // active, and the event loop runs none of its tasks.
        if (self.element.ctx.engine_ctx == null) return;
        // A task runs from the event loop, in no realm: it runs in the
        // element's.
        engine.runTaskInRealm(self.element.ctx, steps, self) catch |err| {
            log.warn("details toggle task not run: {}", .{err});
        };
    }

    /// `Task.drop`: the loop is ending with the task still queued.
    fn drop(data: ?*anyopaque) void {
        const self: *ToggleTask = @ptrCast(@alignCast(data orelse return));
        self.finish();
    }

    /// The task's steps.
    fn steps(data: ?*anyopaque) void {
        const self: *ToggleTask = @ptrCast(@alignCast(data orelse return));
        const element = self.element;
        // 1. Fire an event named toggle at element, using ToggleEvent, with
        // the oldState attribute initialized to oldState and the newState
        // attribute initialized to newState.
        fireToggleEvent(element, self.old_state, self.new_state) catch |err| {
            log.warn("toggle not fired at a details element: {}", .{err});
        };
        // 2. Set element's details toggle task tracker to null. (A listener
        // that toggled the element again queued a task of its own, which
        // runs whatever the tracker says.)
        if (getInternal(element)) |internal| internal.toggle_task = null;
    }

    fn elementIsLive(self: *const ToggleTask) bool {
        return runtime.SlabAllocator.generationOf(self.element) == self.generation;
    }

    /// The task has left the queue, run or not: no tracker may name it, and
    /// the element needs keeping only while another task waits.
    fn finish(self: *ToggleTask) void {
        if (self.elementIsLive()) {
            if (getInternal(self.element)) |internal| {
                if (internal.toggle_task == self) internal.toggle_task = null;
                internal.queued_toggle_tasks -= 1;
                if (internal.queued_toggle_tasks == 0) engine.releasePlatformObject(self.element);
            }
        }
        self.allocator.destroy(self);
    }
};

/// DOM "fire an event": a trusted ToggleEvent, made in the element's realm.
fn fireToggleEvent(element: *runtime.Instance, old_state: []const u8, new_state: []const u8) !void {
    const event = try interfaces.ToggleEvent.call_constructor(
        element.ctx,
        runtime.DOMString.initInterned("toggle"),
        webidl.Opt(dictionaries.ToggleEventInit).passed(.{
            .base = .{},
            .oldState = runtime.DOMString.initInterned(old_state),
            .newState = runtime.DOMString.initInterned(new_state),
        }),
    );
    // A listener can keep the event (`e => last = e`): its wrapper owns it
    // then, and only an event nothing wrapped is freed here.
    const generation = runtime.SlabAllocator.generationOf(event);
    defer event.releaseIfUnwrapped(generation);
    _ = try EventTargetImpl.dispatchTrusted(element, event);
}

/// HTML "queue a details toggle event task" given element, oldState and
/// newState.
fn queueToggleEventTask(element: *runtime.Instance, old_state_given: []const u8, new_state: []const u8) void {
    const internal = getInternal(element) orelse return;
    var old_state = old_state_given;
    // 1. If element's details toggle task tracker is not null: take its old
    // state, remove its task from its task queue, and set the tracker to null.
    // Toggling several times in succession fires one event, from the first
    // state to the last.
    if (internal.toggle_task) |pending| {
        old_state = pending.old_state;
        pending.cancelled = true;
        internal.toggle_task = null;
    }
    // 2. Queue an element task on the DOM manipulation task source given
    // element.
    const loop = element.ctx.getOptionalEventLoop() orelse {
        // A Window realm always has a loop (an iframe's is its parent's); a
        // realm without one is a test's, and the event is lost - loudly.
        log.warn("details toggle event not queued: the element's realm has no event loop", .{});
        return;
    };
    const task = internal.allocator.create(ToggleTask) catch |err| {
        log.warn("details toggle event not queued: {}", .{err});
        return;
    };
    task.* = .{
        .element = element,
        .generation = runtime.SlabAllocator.generationOf(element),
        .old_state = old_state,
        .new_state = new_state,
        .allocator = internal.allocator,
    };
    // A queued task keeps its element alive: `createElement("details")`,
    // `ontoggle` and `open` set, and the element dropped - the toggle still
    // fires, as every browser's queued task keeps the element it targets.
    // The hold is a flag, not a count, so it is taken for the first waiting
    // task and ended with the last.
    if (internal.queued_toggle_tasks == 0) engine.keepPlatformObjectAlive(element);
    internal.queued_toggle_tasks += 1;
    loop.queueTask(.{ .callback = &ToggleTask.run, .context = task, .drop = &ToggleTask.drop });
    // 3. Set element's details toggle task tracker to the task and its old
    // state.
    internal.toggle_task = task;
}
