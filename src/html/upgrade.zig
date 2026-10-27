//! HTML §4.13.5: upgrade an element and try to upgrade an element.
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");
const ce = dom.custom_elements;
const driver = @import("custom_elements/driver.zig");
const html_namespace = "http://www.w3.org/1999/xhtml";

pub const CustomElementState = ce.State;
// Retained for the existing engine-free state fixture; live upgrades read the
// element's state through its owning hook, never through this value object.
pub const UpgradeContext = struct {
    element: *anyopaque,
    definition: *ce.Definition,
    allocator: std.mem.Allocator,
    state: CustomElementState = .undefined,
    is_connected: bool = false,
};

pub fn tryToUpgrade(element: *runtime.Instance) void {
    if (!driver.hasDefinitions(element.ctx)) return;
    // Try-to-upgrade has no state filter: reinserting a precustomized
    // element queues it so a nested scope invokes its earlier callbacks.
    // Only upgradeElement step 1 rejects an already-started upgrade.
    const registry = interfaces.Element.get_customElementRegistry(element) catch return;
    tryUpgradeInRegistry(element, registry) catch {};
}

fn definitionFor(element: *runtime.Instance, registry: ?*runtime.Instance) !?*ce.Definition {
    const data = ce.get(element) orelse return null;
    var namespace = try interfaces.Element.get_namespaceURI(element);
    defer if (namespace) |*value| value.deinit(element.ctx.allocator);
    var name = try interfaces.Element.get_localName(element);
    defer name.deinit(element.ctx.allocator);
    return ce.lookup(registry, if (namespace) |value| value.asSlice() else null, name.asSlice(), data.is_value);
}

fn tryUpgradeInRegistry(element: *runtime.Instance, registry: ?*runtime.Instance) !void {
    // Try-to-upgrade steps 1–2: lookup, then enqueue, never construct here.
    const definition = (try definitionFor(element, registry)) orelse return;
    try driver.enqueueUpgrade(element, definition);
}

/// Returns an OWNED thrown value for the caller to report; null on success.
pub fn upgradeElement(element: *runtime.Instance, definition: *ce.Definition) !?engine.Owned {
    // Steps 1–3: set failed before anything can reenter this algorithm.
    const data = ce.get(element) orelse return null;
    if (data.state != .undefined and data.state != .uncustomized) return null;
    const held_definition = definition.retain();
    defer held_definition.deinit();
    // The element is held across its construction, while the definition's
    // construction stack names it (steps 6-10, constructForUpgrade): refcount
    // step 5e's GCReachableRef in shadow mode - its wrapper rooted, as it
    // always was here, and one counted reference, as WebKit's
    // JSCustomElementInterface keeps the stack as `Vector<RefPtr<Element>, 1>
    // m_constructionStack` (bindings/js/JSCustomElementInterface.h).
    const held = try ce.ElementHold.take(element);
    defer held.release();
    ce.setDefinition(element, definition);
    ce.setState(element, .failed);
    var alive = true;
    errdefer if (alive) clearFailedUpgrade(element);

    // Steps 4–5: snapshot existing attributes in their list order and enqueue
    // connection BEFORE the constructor. Nested CEReactions can invoke them.
    var index: usize = 0;
    while (dom.element_attributes.at(element, index)) |attribute| : (index += 1) {
        try driver.enqueueCallback(element, definition, .attribute_changed, .{ .attribute_changed = .{
            .local_name = attribute.local_name,
            .old_value = null,
            .new_value = attribute.value,
            .namespace = attribute.namespace,
        } });
    }
    if (try interfaces.Node.get_isConnected(element)) try driver.enqueueCallback(element, definition, .connected, .none);

    const result = try constructForUpgrade(element, definition, &alive);
    switch (result) {
        .throw => |exception| {
            // Step 10's final substeps: after restoring the map and popping the
            // construction stack, clear the definition and every queued reaction.
            clearFailedUpgrade(element);
            return exception;
        },
        .normal => |value| value.release(),
    }
    // Step 11: reset the form owner and enqueue form/disabled reactions.
    if (definition.form_associated) ce.refreshFormAfterUpgrade(element);
    // Step 12: only a successful construction makes the element custom.
    ce.setState(element, .custom);
    // A form-associated one is a listed element from now on, with no tree
    // mutation: what is cached under the tree version (a form's elements
    // and named properties, a fieldset's elements) reads again.
    if (definition.form_associated) dom.refcount.formAssociationChanged(element);
    return null;
}

fn clearFailedUpgrade(element: *runtime.Instance) void {
    // Step 10 preserves the failed/precustomized state reached before the
    // exception; only the definition and queued reactions are cleared.
    ce.setDefinition(element, null);
    driver.clearElement(element);
}

fn constructForUpgrade(element: *runtime.Instance, definition: *ce.Definition, alive: *bool) !engine.Completion {
    // Steps 6–9 and the unconditional part of step 10. Both stacks restore
    // after an exception, including a nested construction of the same class.
    try definition.construction_stack.append(definition.allocator, .{ .element = element });
    defer _ = definition.construction_stack.pop();
    const state = try driver.pushConstructor(element.ctx, definition);
    defer state.popConstructor();
    if (definition.disable_shadow and ce.shadowRootOf(element) != null) return .{
        .throw = try engine.createDOMException(element.ctx, "NotSupportedError", "Custom element definition disables shadow roots"),
    };
    // Step 10.2–10.4: Construct, not Call; the binding's HTMLConstructor uses
    // this definition's construction stack and installs the custom prototype.
    ce.setState(element, .precustomized);
    const result = engine.constructCallbackFunction(element.ctx, &definition.constructor, &.{}) catch |err| {
        if (state.active_constructors.get(state.active_constructors.len - 1).?.registry == null) alive.* = false;
        return err;
    };
    if (state.active_constructors.get(state.active_constructors.len - 1).?.registry == null) {
        alive.* = false;
        switch (result) {
            inline else => |value| value.release(),
        }
        return error.InvalidStateError;
    }
    switch (result) {
        .throw => return result,
        .normal => |value| {
            if (engine.sameValue(element.ctx, value.value, .{ .instance = element })) return result;
            value.release();
            return .{ .throw = try engine.createSimpleException(element.ctx, .TypeError, "Custom element constructor returned a different object") };
        },
    }
}

/// CustomElementRegistry.upgrade steps 1–1.3, including a detached root.
pub fn upgradeSubtree(root: *runtime.Instance, registry: *runtime.Instance) !void {
    const base = dom.instance_bridge.getNodeBase(root) orelse return;
    const walk = WalkHold.begin(root, base);
    defer walk.end();
    var candidates = try dom.tree_helpers.getShadowIncludingInclusiveDescendants(registry.ctx.allocator, base);
    defer candidates.deinit();
    for (candidates.toSlice()) |node| {
        if (node.node_type != dom.NodeBase.ELEMENT_NODE) continue;
        const element: *runtime.Instance = @ptrCast(@alignCast(dom.instance_bridge.getInstance(node) orelse continue));
        if (try interfaces.Element.get_customElementRegistry(element) != registry) continue;
        try tryUpgradeInRegistry(element, registry);
    }
}

/// Define steps 17–18, "upgrade particular elements within a document".
/// `document` was checked live by the caller with no engine call since (a
/// scoped registry's document set is weak), and the walk holds it from here.
pub fn enqueueCandidates(registry: *runtime.Instance, document: *runtime.Instance, definition: *ce.Definition) !void {
    const base = dom.instance_bridge.getNodeBase(document) orelse return;
    const walk = WalkHold.begin(document, base);
    defer walk.end();
    var candidates = try dom.tree_helpers.getShadowIncludingDescendants(registry.ctx.allocator, base);
    defer candidates.deinit();
    for (candidates.toSlice()) |node| {
        if (node.node_type != dom.NodeBase.ELEMENT_NODE) continue;
        const element: *runtime.Instance = @ptrCast(@alignCast(dom.instance_bridge.getInstance(node) orelse continue));
        if (try interfaces.Element.get_customElementRegistry(element) != registry) continue;
        // The lookup also checks HTML namespace, local name and is value.
        if (try definitionFor(element, registry) == definition) try driver.enqueueUpgrade(element, definition);
    }
}

/// What a candidate walk holds while it runs (refcount step 5e, lane
/// refcount5). The walk keeps bare tree nodes across driver.enqueueUpgrade,
/// whose wrap of each candidate allocates; a collection there can run
/// teardowns an earlier collection left pending - a document's that a
/// scoped registry's weak document set still lists, freed under the walk
/// when the deferred teardown queue is past its high water
/// (docs/lessons/architecture-a-weak-list-walked-across-an-engine-call-loses-entries-mid-walk.md).
/// So the walk holds its agent's teardowns (engine.holdTeardowns: no script
/// runs in a walk - enqueueUpgrade only queues), and its root with one
/// counted reference, as WebKit's walks hold `RefPtr document` and a
/// `RefPtr element` per step (CustomElementRegistry::addElementDefinition,
/// enqueueUpgradeInShadowIncludingTreeOrder). Each candidate it queues is
/// then held by its reaction record (dom.custom_elements.ElementHold). The
/// cost is two counter changes and a teardown-hold counter per walk.
const WalkHold = struct {
    teardowns: engine.TeardownHold,
    root: *runtime.Instance,
    counted: dom.node_holds.CountedRef,

    fn begin(root: *runtime.Instance, base: *dom.NodeBase) WalkHold {
        var walk: WalkHold = .{ .teardowns = engine.holdTeardowns(root.ctx), .root = root, .counted = .{} };
        walk.counted.take(root, base);
        return walk;
    }

    fn end(self: WalkHold) void {
        var counted = self.counted;
        counted.release(self.root);
        self.teardowns.release();
    }
};

pub fn shouldCreateAsCustomElement(local_name: []const u8, namespace: ?[]const u8, is_value: ?[]const u8, registry: ?*anyopaque) bool {
    return ce.lookup(if (registry) |value| @ptrCast(@alignCast(value)) else null, namespace, local_name, is_value) != null;
}

test "CustomElementState enum" {
    const state = CustomElementState.custom;
    try std.testing.expect(state == .custom);

    const failed = CustomElementState.failed;
    try std.testing.expect(failed == .failed);
}

test "UpgradeContext initialization" {
    const allocator = std.testing.allocator;

    // Mock element and definition
    var mock_element: u8 = 0;

    // Create a mock definition (would normally come from CustomElementRegistry)
    // For testing, we just verify the context struct works
    const ctx = UpgradeContext{
        .element = &mock_element,
        .definition = undefined, // Would be a real definition
        .allocator = allocator,
        .is_connected = true,
    };

    try std.testing.expect(ctx.is_connected == true);
    try std.testing.expect(ctx.state == .undefined);
}

test "shouldCreateAsCustomElement with no registry" {
    // No registry means no custom element definition
    const result = shouldCreateAsCustomElement("my-element", "http://www.w3.org/1999/xhtml", null, null);
    try std.testing.expect(result == false);
}
