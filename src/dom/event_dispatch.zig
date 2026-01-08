// DOM Standard: Event Dispatch Algorithms (§2.9)
// https://dom.spec.whatwg.org/#dispatching-events
//
// This module implements the WHATWG DOM event dispatch algorithm using the
// WebIDL interface/impl pattern. All access to Event and EventTarget internal
// state goes through the impls module, while public API access uses interfaces.

const std = @import("std");
const infra = @import("infra");
const webidl = @import("webidl");
const runtime = @import("runtime");

// Import WebIDL interfaces
const interfaces = @import("interfaces");
const Event = interfaces.Event;
const EventTarget = interfaces.EventTarget;
const Node = interfaces.Node;
const ShadowRoot = interfaces.ShadowRoot;

// Import impls for internal state access
const impls = @import("impls");
const EventImpl = impls.Event;
const EventTargetImpl = impls.EventTarget;
const NodeImpl = impls.Node;

/// Check if a ShadowRoot has mode "closed"
/// Uses @tagName comparison to avoid type mismatches with the generated enum
fn isShadowRootModeClosed(mode: anytype) bool {
    const tag_name = @tagName(mode);
    return std.mem.eql(u8, tag_name, "_closed_");
}

/// Get the root of a node by walking up the parent chain
/// This is a local implementation to avoid dependency on dictionaries module
/// (which would be required for Node.call_getRootNode)
fn getRoot(node: *runtime.Instance) ?*runtime.Instance {
    var current: *runtime.Instance = node;
    while (NodeImpl.get_parentNode(current) catch null) |parent| {
        current = parent;
    }
    return current;
}

/// Get the shadow-including root of a node
/// This follows shadow host chains when encountering shadow roots
/// Equivalent to getRootNode({ composed: true })
fn getShadowIncludingRoot(node: *runtime.Instance) ?*runtime.Instance {
    var current: *runtime.Instance = node;

    while (true) {
        // Get the regular root first
        while (NodeImpl.get_parentNode(current) catch null) |parent| {
            current = parent;
        }

        // Check if this root is a ShadowRoot
        const node_type = NodeImpl.get_nodeType(current) catch return current;
        if (node_type != Node.get_DOCUMENT_FRAGMENT_NODE()) {
            // Not a DocumentFragment, we're done
            return current;
        }

        // It's a DocumentFragment - check if it's a ShadowRoot with a host
        const host = ShadowRoot.get_host(current) catch return current;
        // Continue from the host element
        current = host;
    }
}

// Types from Event impl
const EventPathItem = EventImpl.EventPathItem;

// Types from EventTarget impl
const EventListenerRecord = EventTargetImpl.EventListenerRecord;

/// DOM §2.9.1 - append to an event path
/// To append to an event path, given an event, invocationTarget, shadowAdjustedTarget,
/// relatedTarget, touchTargets, and a slot-in-closed-tree, run these steps:
pub fn appendToEventPath(
    event: *runtime.Instance,
    invocation_target: *runtime.Instance,
    shadow_adjusted_target: ?*runtime.Instance,
    related_target: ?*runtime.Instance,
    touch_targets: infra.List(*runtime.Instance),
    slot_in_closed_tree: bool,
) !void {
    // Step 1: Let invocationTargetInShadowTree be false
    // Step 2: If invocationTarget is a node and its root is a shadow root,
    // then set invocationTargetInShadowTree to true
    var invocation_target_in_shadow_tree = false;

    // Check if invocation_target is a Node by checking node_type
    const target_node_type = EventTargetImpl.getNodeType(invocation_target);
    if (target_node_type > 0) {
        // It's a Node - get root
        if (getRoot(invocation_target)) |root| {
            // Check if root is a ShadowRoot (node_type == DOCUMENT_FRAGMENT_NODE)
            const root_node_type = NodeImpl.get_nodeType(root) catch 0;
            if (root_node_type == Node.get_DOCUMENT_FRAGMENT_NODE()) {
                invocation_target_in_shadow_tree = true;
            }
        }
    }

    // Step 3: Let root-of-closed-tree be false
    // Step 4: If invocationTarget is a shadow root whose mode is "closed",
    // then set root-of-closed-tree to true
    var root_of_closed_tree = false;

    // Check if invocation_target is itself a ShadowRoot
    if (target_node_type == Node.get_DOCUMENT_FRAGMENT_NODE()) {
        // ShadowRoot is a DocumentFragment - check if it's specifically a ShadowRoot
        const mode = ShadowRoot.get_mode(invocation_target) catch null;
        if (mode) |m| {
            if (isShadowRootModeClosed(m)) {
                root_of_closed_tree = true;
            }
        }
    }

    // Step 5: Append a new struct to event's path
    const path_item = EventPathItem{
        .invocation_target = invocation_target,
        .invocation_target_in_shadow_tree = invocation_target_in_shadow_tree,
        .shadow_adjusted_target = shadow_adjusted_target,
        .related_target = related_target,
        .touch_target_list = touch_targets,
        .root_of_closed_tree = root_of_closed_tree,
        .slot_in_closed_tree = slot_in_closed_tree,
    };

    // Get the path from event's internal state and append
    const path = EventImpl.getPath(event) orelse return error.InvalidState;
    try path.append(path_item);
}

/// DOM §2.9 - dispatch
/// To dispatch an event to a target, with an optional legacy target override flag
/// and an optional legacyOutputDidListenersThrowFlag, run these steps:
pub fn dispatch(
    event: *runtime.Instance,
    target: *runtime.Instance,
    legacy_target_override_flag: bool,
    legacy_output_did_listeners_throw_flag_param: ?*bool,
) !bool {
    const allocator = event.ctx.allocator;

    const debug_event_type = Event.get_type(event) catch runtime.DOMString.initInterned("");
    std.debug.print("[dispatch] ENTRY: event_type='{s}', target={*}\n", .{ debug_event_type.asSlice(), target });

    // Pass through to invoke function
    const legacy_output_did_listeners_throw_flag = legacy_output_did_listeners_throw_flag_param;

    // Step 1: Set event's dispatch flag
    EventImpl.setDispatchFlag(event, true);

    // Step 2: Let targetOverride be target, if legacy target override flag is not given,
    // and target's associated Document otherwise
    const target_override = if (!legacy_target_override_flag) target else blk: {
        // Get target's associated Document
        // Per DOM spec: Every Node has an owner_document
        const target_node_type = EventTargetImpl.getNodeType(target);
        if (target_node_type > 0) {
            const owner_doc = Node.get_ownerDocument(target) catch null;
            if (owner_doc) |doc| {
                break :blk doc;
            }
        }
        // Fallback: if not a node or has no document, use target itself
        break :blk target;
    };

    // Step 3: Let activationTarget be null
    var activation_target: ?*runtime.Instance = null;

    // Step 4: Let relatedTarget be the result of retargeting event's relatedTarget against target
    const event_related_target = EventImpl.getRelatedTarget(event);
    const related_target = retarget(event_related_target, target);

    // Step 5: Let clearTargets be false
    var clear_targets = false;

    // Step 6: If target is not relatedTarget or target is event's relatedTarget
    if (target != related_target or target == event_related_target) {
        // Step 6.1: Let touchTargets be a new list
        var touch_targets = infra.List(*runtime.Instance).init(allocator);

        // Step 6.2: For each touchTarget of event's touch target list,
        // append the result of retargeting touchTarget against target to touchTargets
        const event_touch_targets = EventImpl.getTouchTargetList(event);
        if (event_touch_targets) |ttl| {
            for (ttl.toSlice()) |touch_target| {
                const retargeted = retarget(touch_target, target);
                if (retargeted) |t| {
                    try touch_targets.append(t);
                }
            }
        }

        // Step 6.3: Append to an event path
        try appendToEventPath(event, target, target_override, related_target, touch_targets, false);

        // Step 6.4: Let isActivationEvent be true if event is MouseEvent and type is "click"
        const event_type = Event.get_type(event) catch runtime.DOMString.initInterned("");
        const is_activation_event = std.mem.eql(u8, event_type.asSlice(), "click");

        // Step 6.5: If isActivationEvent and target has activation behavior, set activationTarget
        if (is_activation_event and hasActivationBehavior(target)) {
            activation_target = target;
        }

        // Step 6.12: If activationTarget is non-null and has legacy-pre-activation behavior, run it
        if (activation_target) |act_target| {
            if (hasLegacyPreActivationBehavior(act_target)) {
                runLegacyPreActivationBehavior(act_target);
            }
        }

        // Step 6.6: Let slottable be target, if target is a slottable and is assigned
        var slottable: ?*runtime.Instance = null;

        // Check if target is an Element or Text (slottables)
        const target_node_type = EventTargetImpl.getNodeType(target);
        if (target_node_type > 0) {
            if (target_node_type == Node.get_ELEMENT_NODE()) {
                // Check if assigned to a slot
                const assigned_slot = interfaces.Element.get_assignedSlot(target) catch null;
                if (assigned_slot != null) {
                    slottable = target;
                }
            }
        }

        // Step 6.7: Let slot-in-closed-tree be false
        var slot_in_closed_tree = false;

        // Step 6.8: Let parent be the result of invoking target's get the parent with event
        var parent = getTheParent(target, event);

        // Step 6.9: While parent is non-null
        while (parent) |p| {
            // Step 6.9.1-2: Handle slottable
            if (slottable != null) {
                // Step 6.9.2: Set slottable to null
                slottable = null;

                // Step 6.9.2 continued: If parent's root is a shadow root whose mode is "closed",
                // set slot-in-closed-tree to true
                const parent_node_type = EventTargetImpl.getNodeType(p);
                if (parent_node_type > 0) {
                    if (getRoot(p)) |root| {
                        const root_node_type = NodeImpl.get_nodeType(root) catch 0;
                        if (root_node_type == Node.get_DOCUMENT_FRAGMENT_NODE()) {
                            const shadow_mode = ShadowRoot.get_mode(root) catch null;
                            if (shadow_mode) |m| {
                                if (isShadowRootModeClosed(m)) {
                                    slot_in_closed_tree = true;
                                }
                            }
                        }
                    }
                }
            }

            // Step 6.9.3: If parent is a slottable and is assigned, set slottable to parent
            const parent_node_type = EventTargetImpl.getNodeType(p);
            if (parent_node_type > 0) {
                if (parent_node_type == Node.get_ELEMENT_NODE()) {
                    const assigned_slot = interfaces.Element.get_assignedSlot(p) catch null;
                    if (assigned_slot != null) {
                        slottable = p;
                    }
                }
            }

            // Step 6.9.4: Let relatedTarget be result of retargeting event's relatedTarget against parent
            const parent_related_target = retarget(event_related_target, p);

            // Step 6.9.5: Let touchTargets be a new list
            var parent_touch_targets = infra.List(*runtime.Instance).init(allocator);
            defer parent_touch_targets.deinit();

            // Step 6.9.6: For each touchTarget of event's touch target list,
            // append the result of retargeting touchTarget against parent to touchTargets
            if (event_touch_targets) |ttl| {
                for (ttl.toSlice()) |touch_target| {
                    const retargeted_touch = retarget(touch_target, p);
                    if (retargeted_touch) |t| {
                        try parent_touch_targets.append(t);
                    }
                }
            }

            // Step 6.9.7: If parent is a Window object, or parent is a node and target's root
            // is a shadow-including inclusive ancestor of parent
            var should_append = false;

            // Check if parent is a node AND target's root is shadow-including inclusive ancestor
            if (parent_node_type > 0) {
                // Parent is a Node
                // Get target's shadow-including root (composed: true)
                if (getShadowIncludingRoot(target)) |tr| {
                    // Check if target_root is shadow-including inclusive ancestor of parent
                    if (isShadowIncludingInclusiveAncestor(tr, p)) {
                        should_append = true;
                    }
                }
            }

            if (should_append) {
                // Step 6.9.7 continued: Append to event path
                try appendToEventPath(event, p, null, parent_related_target, parent_touch_targets, slot_in_closed_tree);
            }
            // Step 6.9.8: Otherwise, if parent is relatedTarget, set parent to null
            else if (p == parent_related_target) {
                parent = null;
                continue;
            }
            // Step 6.9.9: Otherwise, append to event path with event target set to target
            else {
                try appendToEventPath(event, p, target, parent_related_target, parent_touch_targets, slot_in_closed_tree);
            }

            // Step 6.9.10: If parent is non-null, set parent to result of invoking parent's get the parent
            parent = getTheParent(p, event);

            // Step 6.9.11: Set slot-in-closed-tree to false
            slot_in_closed_tree = false;
        }

        // Step 6.10-6.11: Check for clearTargets based on shadow roots in path
        const path = EventImpl.getPath(event);
        if (path) |p| {
            const items = p.toSlice();
            // Find last struct with shadow-adjusted target
            var i = items.len;
            while (i > 0) {
                i -= 1;
                const item = items[i];
                if (item.shadow_adjusted_target != null) {
                    // Check if this or related_target contains shadow root nodes
                    if (item.root_of_closed_tree or item.slot_in_closed_tree) {
                        clear_targets = true;
                    }
                    break;
                }
            }
        }

        // Step 6.13: For each struct in event's path, in reverse order (capturing phase)
        if (path) |p| {
            const items = p.toSlice();
            for (items, 0..) |_, idx| {
                const path_idx = items.len - 1 - idx;
                const path_struct = items[path_idx];

                // Set event phase
                if (path_struct.shadow_adjusted_target != null) {
                    EventImpl.setEventPhase(event, Event.get_AT_TARGET());
                } else {
                    EventImpl.setEventPhase(event, Event.get_CAPTURING_PHASE());
                }

                // Invoke listeners in capturing phase
                try invoke(event, path_struct, "capturing", legacy_output_did_listeners_throw_flag);
            }

            // Step 6.14: For each struct in event's path (bubbling phase)
            for (items) |path_struct| {
                // Set event phase
                if (path_struct.shadow_adjusted_target != null) {
                    EventImpl.setEventPhase(event, Event.get_AT_TARGET());
                } else {
                    // If event's bubbles is false, continue
                    const bubbles = Event.get_bubbles(event) catch false;
                    if (!bubbles) continue;
                    EventImpl.setEventPhase(event, Event.get_BUBBLING_PHASE());
                }

                // Invoke listeners in bubbling phase
                try invoke(event, path_struct, "bubbling", legacy_output_did_listeners_throw_flag);
            }
        }

        // Step 6.12: If activationTarget is non-null and has legacy-pre-activation behavior, run it
        if (activation_target) |act_target| {
            if (hasLegacyPreActivationBehavior(act_target)) {
                runLegacyPreActivationBehavior(act_target);
            }
        }
    }

    // Step 7: Set event's eventPhase attribute to NONE
    EventImpl.setEventPhase(event, Event.get_NONE());

    // Step 8: Set event's currentTarget attribute to null
    EventImpl.setCurrentTarget(event, null);

    // Step 9: Set event's path to the empty list
    if (EventImpl.getPath(event)) |path| {
        // Clear all items in the path
        const slice = path.toSliceMut();
        for (slice) |*item| {
            item.touch_target_list.deinit();
        }
        path.clear();
    }

    // Step 10: Unset event's dispatch flag, stop propagation flag, and stop immediate propagation flag
    EventImpl.setDispatchFlag(event, false);
    // Note: stop propagation flags are reset via internal state

    // Step 11: If clearTargets is true, clear targets
    if (clear_targets) {
        EventImpl.setTarget(event, null);
        EventImpl.setRelatedTarget(event, null);
        if (EventImpl.getTouchTargetList(event)) |ttl| {
            ttl.clear();
        }
    }

    // Step 12: If activationTarget is non-null, run activation behavior
    if (activation_target) |act_target| {
        // Step 12.1: If event's canceled flag is unset, run activationTarget's activation behavior
        if (!EventImpl.getCanceledFlag(event)) {
            runActivationBehavior(act_target, event);
        }
        // Step 12.2: Otherwise, if activationTarget has legacy-canceled-activation behavior, run it
        else if (hasLegacyCanceledActivationBehavior(act_target)) {
            runLegacyCanceledActivationBehavior(act_target);
        }
    }

    // Step 13: Return false if event's canceled flag is set; otherwise true
    return !EventImpl.getCanceledFlag(event);
}

/// DOM §2.9 - retarget
///
/// To retarget an object A against an object B, repeat these steps until they return an object:
/// 1. If one of the following is true, return A:
///    - A is not a node
///    - A's root is not a shadow root
///    - B is a node and A's root is a shadow-including inclusive ancestor of B
/// 2. Set A to A's root's host
///
/// Spec: https://dom.spec.whatwg.org/#retarget
fn retarget(a: ?*runtime.Instance, b: *runtime.Instance) ?*runtime.Instance {
    var current_a = a;

    while (current_a) |a_target| {
        // Step 1: Check if we should return A

        // Step 1.1: If A is not a node, return A
        const a_node_type = EventTargetImpl.getNodeType(a_target);
        if (a_node_type == 0) {
            return a_target;
        }

        // Step 1.2: If A's root is not a shadow root, return A
        const a_root = getRoot(a_target) orelse return a_target;
        const a_root_node_type = NodeImpl.get_nodeType(a_root) catch 0;
        if (a_root_node_type != Node.get_DOCUMENT_FRAGMENT_NODE()) {
            return a_target;
        }

        // A's root is a shadow root

        // Step 1.3: If B is a node and A's root is a shadow-including inclusive ancestor of B
        const b_node_type = EventTargetImpl.getNodeType(b);
        if (b_node_type > 0) {
            // Check if A's root is shadow-including inclusive ancestor of B
            if (isShadowIncludingInclusiveAncestor(a_root, b)) {
                return a_target;
            }
        }

        // Step 2: Set A to A's root's host
        const host = ShadowRoot.get_host(a_root) catch {
            return null;
        };
        current_a = host;
    }

    // If A becomes null, return null
    return null;
}

/// Check if ancestor is a shadow-including inclusive ancestor of node
/// DOM §4.2.2.4: A is a shadow-including inclusive ancestor of B if:
/// - A is an inclusive ancestor of B, OR
/// - B's root is a shadow root and A is a shadow-including inclusive ancestor of B's host
fn isShadowIncludingInclusiveAncestor(ancestor: *runtime.Instance, node: *runtime.Instance) bool {
    // Check if ancestor is an inclusive ancestor of node
    if (isInclusiveAncestor(ancestor, node)) {
        return true;
    }

    // Check if node's root is a shadow root
    const node_root = getRoot(node) orelse return false;
    const root_node_type = NodeImpl.get_nodeType(node_root) catch 0;
    if (root_node_type == Node.get_DOCUMENT_FRAGMENT_NODE()) {
        // Get shadow root's host
        const host = ShadowRoot.get_host(node_root) catch {
            return false;
        };

        // Recursively check if ancestor is shadow-including inclusive ancestor of host
        return isShadowIncludingInclusiveAncestor(ancestor, host);
    }

    return false;
}

/// Check if ancestor is an inclusive ancestor of node
/// DOM §4.2.2.2: An inclusive ancestor is an object or one of its ancestors.
fn isInclusiveAncestor(ancestor: *runtime.Instance, node: *runtime.Instance) bool {
    if (ancestor == node) {
        return true;
    }
    return isAncestor(ancestor, node);
}

/// Check if ancestor is an ancestor of node
/// DOM §4.2.2.1: An object A is an ancestor of an object B if and only if B is a descendant of A.
fn isAncestor(ancestor: *runtime.Instance, node: *runtime.Instance) bool {
    // Walk up the tree from node, checking if we find ancestor
    var current_opt = Node.get_parentNode(node) catch null;
    while (current_opt) |current| {
        if (current == ancestor) {
            return true;
        }
        current_opt = Node.get_parentNode(current) catch null;
    }
    return false;
}

/// DOM §2.9 - get the parent
/// Each EventTarget has an associated get the parent algorithm
/// DOM §2.9 - get the parent
/// Each EventTarget has an associated "get the parent" algorithm.
/// Nodes, shadow roots, and documents override this algorithm.
fn getTheParent(target: *runtime.Instance, event: *runtime.Instance) ?*runtime.Instance {
    // Per spec (DOM §2.9): Each EventTarget has a "get the parent" algorithm
    // For Node: return parent, unless event.composed is false and node is a shadow root, then return null
    // For ShadowRoot: if event.composed is false, return null; otherwise return host

    // Check if this is a Node
    const target_node_type = EventTargetImpl.getNodeType(target);
    if (target_node_type > 0) {
        // Check if this is a ShadowRoot
        if (target_node_type == Node.get_DOCUMENT_FRAGMENT_NODE()) {
            // This might be a ShadowRoot
            // If event.composed is false, return null (don't cross shadow boundary)
            const composed = Event.get_composed(event) catch false;
            if (!composed) {
                return null;
            }

            // If composed is true, return the host
            const host = ShadowRoot.get_host(target) catch {
                // Not a ShadowRoot, just a DocumentFragment - return parent
                return Node.get_parentNode(target) catch null;
            };
            return host;
        }

        // Regular Node - check if assigned to a slot
        // Per spec: If node is assigned, return node's assigned slot
        if (target_node_type == Node.get_ELEMENT_NODE()) {
            const assigned_slot = interfaces.Element.get_assignedSlot(target) catch null;
            if (assigned_slot) |slot| {
                return slot;
            }
        }

        // Return parent_node
        return Node.get_parentNode(target) catch null;
    }

    return null;
}

/// DOM §2.9 - invoke
/// Invoke event listeners for a given struct in the event path
fn invoke(
    event: *runtime.Instance,
    path_struct: EventPathItem,
    phase: []const u8,
    legacy_output_did_listeners_throw_flag: ?*bool,
) !void {
    const allocator = event.ctx.allocator;

    // Step 1: Set event's target to the shadow-adjusted target of the last struct
    // in event's path that is either this struct or preceding it, whose shadow-adjusted target is non-null
    const path = EventImpl.getPath(event) orelse return;
    for (path.toSlice()) |item| {
        if (item.shadow_adjusted_target) |target| {
            if (@intFromPtr(&item) <= @intFromPtr(&path_struct)) {
                EventImpl.setTarget(event, target);
            }
        }
    }

    // Step 2: Set event's relatedTarget to struct's relatedTarget
    EventImpl.setRelatedTarget(event, path_struct.related_target);

    // Step 3: Set event's touch target list to struct's touch target list
    if (EventImpl.getTouchTargetList(event)) |ttl| {
        ttl.clear();
        try ttl.appendSlice(path_struct.touch_target_list.toSlice());
    }

    // Step 4: If event's stop propagation flag is set, return
    if (EventImpl.getStopPropagationFlag(event)) return;

    // Step 5: Initialize event's currentTarget attribute to struct's invocation target
    EventImpl.setCurrentTarget(event, path_struct.invocation_target);

    // Step 6: Let listeners be a clone of event's currentTarget's event listener list
    const current_target = path_struct.invocation_target;

    std.debug.print("[invoke] current_target={*}, phase={s}\n", .{ current_target, phase });

    var listeners = infra.List(EventListenerRecord).init(allocator);
    defer listeners.deinit();

    // Get the event_listener_list from EventTarget
    const internal = EventTargetImpl.getInternalState(current_target);
    std.debug.print("[invoke] internal={?*}\n", .{internal});
    if (internal) |int| {
        const listener_list = int.getEventListenerList();
        std.debug.print("[invoke] listener_list.len={d}\n", .{listener_list.len});
        for (listener_list, 0..) |listener, i| {
            std.debug.print("[invoke] listener[{d}]: type='{s}', callback={?*}, removed={}\n", .{
                i,
                listener.type.asSlice(),
                listener.callback,
                listener.removed,
            });
        }
        try listeners.appendSlice(listener_list);
    } else {
        std.debug.print("[invoke] No internal state found for current_target!\n", .{});
    }

    // Step 7: Let invocationTargetInShadowTree be struct's invocation-target-in-shadow-tree
    const invocation_target_in_shadow_tree = path_struct.invocation_target_in_shadow_tree;

    // Step 8: Let found be the result of running inner invoke
    const found = try innerInvoke(
        event,
        listeners.toSlice(),
        phase,
        invocation_target_in_shadow_tree,
        legacy_output_did_listeners_throw_flag,
    );

    // Step 9: If found is false and event's isTrusted attribute is true, handle legacy event types
    const is_trusted = Event.get_isTrusted(event) catch false;
    if (!found and is_trusted) {
        // Step 9.1: Let originalEventType be event's type attribute value
        const original_event_type = Event.get_type(event) catch return;

        // Step 9.2: Check for legacy event type mappings
        const legacy_type = getLegacyEventType(original_event_type.asSlice());
        if (legacy_type) |_| {
            // Step 9.3: Inner invoke with legacy type
            // Note: This would require temporarily changing the event type
            // For now, we just call innerInvoke again
            _ = try innerInvoke(
                event,
                listeners.toSlice(),
                phase,
                invocation_target_in_shadow_tree,
                legacy_output_did_listeners_throw_flag,
            );
        }
    }
}

/// INTEGRATION POINT: Callback Invocation
/// Invokes an event listener callback with the given event.
///
/// Per DOM spec:
/// - Call callback.handleEvent(event) for object callbacks
/// - Call callback(event) for function callbacks
/// - Catch and report exceptions
/// - Set legacy_flag to true if exception is thrown
/// - Return true if callback was invoked successfully
fn invokeCallback(
    callback: ?*runtime.Instance,
    event: *runtime.Instance,
    legacy_flag: ?*bool,
) bool {
    // Delegate to EventTargetImpl which has access to V8 bindings
    return EventTargetImpl.invokeEventListenerCallback(callback, event, legacy_flag);
}

/// DOM §2.9 - inner invoke
/// Inner invoke algorithm that actually calls the listeners
fn innerInvoke(
    event: *runtime.Instance,
    listeners: []const EventListenerRecord,
    phase: []const u8,
    invocation_target_in_shadow_tree: bool,
    legacy_output_did_listeners_throw_flag: ?*bool,
) !bool {
    // Step 1: Let found be false
    var found = false;

    // Get event type for comparison
    const event_type = Event.get_type(event) catch return found;

    std.debug.print("[innerInvoke] event_type='{s}', listeners.len={d}, phase={s}\n", .{
        event_type.asSlice(),
        listeners.len,
        phase,
    });

    // Step 2: For each listener of listeners, whose removed is false
    for (listeners, 0..) |listener, i| {
        if (listener.removed) {
            std.debug.print("[innerInvoke] listener[{d}] removed, skipping\n", .{i});
            continue;
        }

        // Step 2.1: If event's type attribute value is not listener's type, then continue
        if (!std.mem.eql(u8, event_type.asSlice(), listener.type.asSlice())) {
            std.debug.print("[innerInvoke] listener[{d}] type mismatch: event='{s}' vs listener='{s}'\n", .{
                i,
                event_type.asSlice(),
                listener.type.asSlice(),
            });
            continue;
        }

        std.debug.print("[innerInvoke] listener[{d}] TYPE MATCHED! invoking callback={?*}\n", .{ i, listener.callback });

        // Step 2.2: Set found to true
        found = true;

        // Step 2.3: If phase is "capturing" and listener's capture is false, then continue
        if (std.mem.eql(u8, phase, "capturing") and !listener.capture) continue;

        // Step 2.4: If phase is "bubbling" and listener's capture is true, then continue
        if (std.mem.eql(u8, phase, "bubbling") and listener.capture) continue;

        // Step 2.5: If listener's once is true, then remove the event listener
        if (listener.once) {
            const current_target = EventImpl.getPath(event);
            _ = current_target;
            // TODO: Actually remove the listener from the EventTarget
        }

        // Step 2.6-8: Handle global and currentEvent (Window-specific)
        // TODO: Implement when Window object is available
        _ = invocation_target_in_shadow_tree;

        // Step 2.9: If listener's passive is true, set event's in passive listener flag
        if (listener.passive orelse false) {
            EventImpl.setInPassiveListenerFlag(event, true);
        }

        // Step 2.10: Record timing info (performance API integration)
        // TODO: Implement when Performance API is available

        // Step 2.11: Call the listener's callback
        const callback_invoked = invokeCallback(listener.callback, event, legacy_output_did_listeners_throw_flag);
        _ = callback_invoked;

        // Step 2.12: Unset event's in passive listener flag
        EventImpl.setInPassiveListenerFlag(event, false);

        // Step 2.13: Reset currentEvent (Window-specific)
        // TODO: Implement when Window object is available

        // Step 2.14: If event's stop immediate propagation flag is set, then break
        if (EventImpl.getStopImmediatePropagationFlag(event)) break;
    }

    // Step 3: Return found
    return found;
}

/// Get legacy event type for compatibility
fn getLegacyEventType(event_type: []const u8) ?[]const u8 {
    if (std.mem.eql(u8, event_type, "animationend")) return "webkitAnimationEnd";
    if (std.mem.eql(u8, event_type, "animationiteration")) return "webkitAnimationIteration";
    if (std.mem.eql(u8, event_type, "animationstart")) return "webkitAnimationStart";
    if (std.mem.eql(u8, event_type, "transitionend")) return "webkitTransitionEnd";
    return null;
}

/// DOM §2.9 - Check if EventTarget has activation behavior
fn hasActivationBehavior(target: *runtime.Instance) bool {
    _ = target;
    // TODO: Check if target has activation behavior
    return false;
}

/// DOM §2.9 - Run activation behavior
fn runActivationBehavior(target: *runtime.Instance, event: *runtime.Instance) void {
    _ = target;
    _ = event;
    // TODO: Execute target's activation behavior algorithm
}

/// DOM §2.9 - Check if EventTarget has legacy-pre-activation behavior
fn hasLegacyPreActivationBehavior(target: *runtime.Instance) bool {
    _ = target;
    return false;
}

/// DOM §2.9 - Run legacy-pre-activation behavior
fn runLegacyPreActivationBehavior(target: *runtime.Instance) void {
    _ = target;
}

/// DOM §2.9 - Check if EventTarget has legacy-canceled-activation behavior
fn hasLegacyCanceledActivationBehavior(target: *runtime.Instance) bool {
    _ = target;
    return false;
}

/// DOM §2.9 - Run legacy-canceled-activation behavior
fn runLegacyCanceledActivationBehavior(target: *runtime.Instance) void {
    _ = target;
}
