// DOM Standard: Event Dispatch Algorithms (§2.9)
// https://dom.spec.whatwg.org/#dispatching-events

const std = @import("std");
const infra = @import("infra");
const webidl = @import("webidl");
const Event = @import("event").Event;
const EventTarget = @import("event_target").EventTarget;
const EventListener = @import("event_target").EventListener;
const EventPathItem = Event.EventPathItem;
const Node = @import("node").Node;
const Element = @import("element").Element;
const ShadowRoot = @import("shadow_root").ShadowRoot;
const ShadowRootMode = @import("shadow_root").ShadowRootMode;

/// DOM §2.9.1 - append to an event path
/// To append to an event path, given an event, invocationTarget, shadowAdjustedTarget,
/// relatedTarget, touchTargets, and a slot-in-closed-tree, run these steps:
pub fn appendToEventPath(
    event: *Event,
    invocation_target: *EventTarget,
    shadow_adjusted_target: ?*EventTarget,
    related_target: ?*EventTarget,
    touch_targets: infra.List(*EventTarget),
    slot_in_closed_tree: bool,
) !void {
    // Step 1: Let invocationTargetInShadowTree be false
    // Step 2: If invocationTarget is a node and its root is a shadow root,
    // then set invocationTargetInShadowTree to true
    var invocation_target_in_shadow_tree = false;

    // Check if invocation_target is a Node by checking its type_tag
    // Non-Node types: EventTarget, AbortSignal
    // Node types: Everything else (Element, Document, Text, etc.)
    if (invocation_target.type_tag != .EventTarget and
        invocation_target.type_tag != .AbortSignal)
    {
        // It's a Node - cast to Node to get root
        const node: *Node = @ptrCast(@alignCast(invocation_target));
        const root_node = node.call_getRootNode(.{});

        // Check if root is a ShadowRoot using NodeBase type_tag
        const NodeTypeTag = @import("node").NodeTypeTag;
        if (root_node.base.type_tag == NodeTypeTag.ShadowRoot) {
            invocation_target_in_shadow_tree = true;
        }
    }

    // Step 3: Let root-of-closed-tree be false
    // Step 4: If invocationTarget is a shadow root whose mode is "closed",
    // then set root-of-closed-tree to true
    var root_of_closed_tree = false;

    // Check if invocation_target is itself a ShadowRoot
    const NodeTypeTag = @import("node").NodeTypeTag;
    if (invocation_target.type_tag != .EventTarget and invocation_target.type_tag != .AbortSignal) {
        const node: *Node = @ptrCast(@alignCast(invocation_target));
        if (node.base.type_tag == NodeTypeTag.ShadowRoot) {
            // It's a ShadowRoot - cast and check mode
            const shadow: *ShadowRoot = @ptrCast(@alignCast(node));
            if (shadow.getMode() == ShadowRootMode.closed) {
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

    try event.path.append(path_item);
}

/// DOM §2.9 - dispatch
/// To dispatch an event to a target, with an optional legacy target override flag
/// and an optional legacyOutputDidListenersThrowFlag, run these steps:
pub fn dispatch(
    event: *Event,
    target: *EventTarget,
    legacy_target_override_flag: bool,
    legacy_output_did_listeners_throw_flag_param: ?*bool,
) !bool {
    // Pass through to invoke function
    const legacy_output_did_listeners_throw_flag = legacy_output_did_listeners_throw_flag_param;

    // Step 1: Set event's dispatch flag
    event.dispatch_flag = true;

    // Step 2: Let targetOverride be target, if legacy target override flag is not given,
    // and target's associated Document otherwise
    const target_override = if (!legacy_target_override_flag) target else blk: {
        // Get target's associated Document
        // Per DOM spec: Every Node has an owner_document
        if (target.type_tag != .EventTarget and target.type_tag != .AbortSignal) {
            const node: *Node = @ptrCast(@alignCast(target));
            if (node.owner_document) |doc| {
                // Return the document as EventTarget
                const doc_node: *Node = @ptrCast(@alignCast(doc));
                break :blk &doc_node.base;
            }
        }
        // Fallback: if not a node or has no document, use target itself
        break :blk target;
    };

    // Step 3: Let activationTarget be null
    var activation_target: ?*EventTarget = null;

    // Step 4: Let relatedTarget be the result of retargeting event's relatedTarget against target
    const related_target = retarget(event.related_target, target);

    // Step 5: Let clearTargets be false
    const clear_targets = false;

    // Step 6: If target is not relatedTarget or target is event's relatedTarget
    if (target != related_target or target == event.related_target) {
        // Step 6.1: Let touchTargets be a new list
        var touch_targets = infra.List(*EventTarget).init(event.allocator);

        // Step 6.2: For each touchTarget of event's touch target list,
        // append the result of retargeting touchTarget against target to touchTargets
        for (event.touch_target_list.items()) |touch_target| {
            const retargeted = retarget(touch_target, target);
            if (retargeted) |t| {
                try touch_targets.append(t);
            }
        }

        // Step 6.3: Append to an event path
        try appendToEventPath(event, target, target_override, related_target, touch_targets, false);

        // Step 6.4: Let isActivationEvent be true if event is MouseEvent and type is "click"
        // Check if event type is "click" (MouseEvent check TODO: requires MouseEvent type)
        const is_activation_event = std.mem.eql(u8, event.event_type, "click");

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
        // A slottable is an Element or Text node that can be assigned to a slot
        var slottable: ?*EventTarget = null;

        // Check if target is an Element or Text (slottables)
        if (target.type_tag != .EventTarget and target.type_tag != .AbortSignal) {
            // It's a Node - check if it's Element or Text
            const node: *Node = @ptrCast(@alignCast(target));
            if (node.base.type_tag == .Element) {
                const element: *const Element = @ptrCast(@alignCast(node));
                if (element.isAssigned()) {
                    slottable = target;
                }
            } else if (node.base.type_tag == .Text) {
                // Text nodes are also slottable
                // They have an assigned_slot field too (from Slottable mixin)
                // For now, we'll treat them similarly to elements
                // TODO: Verify Text has assigned_slot field when Text.zig is generated with Slottable
                // For safety, only handle Element for now until Text Slottable is confirmed
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
                // Step 6.9.1: Assert: parent is a slot (HTMLSlotElement)
                // We don't have HTMLSlotElement yet, so we can't verify this

                // Step 6.9.2: Set slottable to null
                slottable = null;

                // Step 6.9.2 continued: If parent's root is a shadow root whose mode is "closed",
                // set slot-in-closed-tree to true
                if (p.type_tag != .EventTarget and p.type_tag != .AbortSignal) {
                    const parent_node: *Node = @ptrCast(@alignCast(p));
                    const parent_root = parent_node.call_getRootNode(.{});
                    const NodeTypeTag = @import("node").NodeTypeTag;
                    if (parent_root.base.type_tag == NodeTypeTag.ShadowRoot) {
                        const shadow: *ShadowRoot = @ptrCast(@alignCast(parent_root));
                        if (shadow.getMode() == ShadowRootMode.closed) {
                            slot_in_closed_tree = true;
                        }
                    }
                }
            }

            // Step 6.9.3: If parent is a slottable and is assigned, set slottable to parent
            if (p.type_tag != .EventTarget and p.type_tag != .AbortSignal) {
                const parent_node: *Node = @ptrCast(@alignCast(p));
                if (parent_node.base.type_tag == .Element) {
                    const parent_element: *const Element = @ptrCast(@alignCast(parent_node));
                    if (parent_element.isAssigned()) {
                        slottable = p;
                    }
                }
            }

            // Step 6.9.4: Let relatedTarget be result of retargeting event's relatedTarget against parent
            const parent_related_target = retarget(event.related_target, p);

            // Step 6.9.5: Let touchTargets be a new list
            var parent_touch_targets = infra.List(*EventTarget).init(event.allocator);
            defer parent_touch_targets.deinit();

            // Step 6.9.6: For each touchTarget of event's touch target list,
            // append the result of retargeting touchTarget against parent to touchTargets
            for (event.touch_target_list.items()) |touch_target| {
                const retargeted_touch = retarget(touch_target, p);
                if (retargeted_touch) |t| {
                    try parent_touch_targets.append(t);
                }
            }

            // Step 6.9.7: If parent is a Window object, or parent is a node and target's root
            // is a shadow-including inclusive ancestor of parent
            var should_append = false;

            // Check if parent is a Window object (HTML spec - not implemented)
            // For now, Window is not implemented, so this is always false

            // Check if parent is a node AND target's root is shadow-including inclusive ancestor
            if (p.type_tag != .EventTarget and p.type_tag != .AbortSignal) {
                // Parent is a Node
                // Get target's shadow-including root
                const target_node: *Node = @ptrCast(@alignCast(target));
                const target_root = target_node.call_getRootNode(.{ .composed = true }); // shadow-including

                // Check if target_root is shadow-including inclusive ancestor of parent
                const parent_node: *Node = @ptrCast(@alignCast(p));
                if (isShadowIncludingInclusiveAncestor(target_root, parent_node)) {
                    should_append = true;
                }
            }

            if (should_append) {
                // Step 6.9.7 continued: Append to event path
                try appendToEventPath(event, p, null, parent_related_target, parent_touch_targets, slot_in_closed_tree);
            }
            // Step 6.9.8: Otherwise, if parent is relatedTarget, set parent to null
            else if (p == parent_related_target) {
                parent = null;
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

        // Step 6.10: Let clearTargetsStruct be the last struct in event's path whose shadow-adjusted target is non-null
        // Step 6.11: Check if clearTargetsStruct contains shadow root nodes, set clearTargets accordingly
        // (Shadow DOM not implemented, so clearTargets remains false)

        // Step 6.12: If activationTarget is non-null and has legacy-pre-activation behavior, run it
        // (Legacy activation not implemented yet)

        // Step 6.13: For each struct in event's path, in reverse order (capturing phase)
        for (event.path.items, 0..) |_, i| {
            const idx = event.path.items.len - 1 - i;
            const path_struct = event.path.items[idx];

            // Set event phase
            if (path_struct.shadow_adjusted_target != null) {
                event.event_phase = Event.AT_TARGET;
            } else {
                event.event_phase = Event.CAPTURING_PHASE;
            }

            // Invoke listeners in capturing phase
            try invoke(event, path_struct, "capturing", legacy_output_did_listeners_throw_flag);
        }

        // Step 6.14: For each struct in event's path (bubbling phase)
        for (event.path.items) |path_struct| {
            // Set event phase
            if (path_struct.shadow_adjusted_target != null) {
                event.event_phase = Event.AT_TARGET;
            } else {
                // If event's bubbles is false, continue
                if (!event.bubbles) continue;
                event.event_phase = Event.BUBBLING_PHASE;
            }

            // Invoke listeners in bubbling phase
            try invoke(event, path_struct, "bubbling", legacy_output_did_listeners_throw_flag);
        }

        // Step 6.12: If activationTarget is non-null and has legacy-pre-activation behavior, run it
        if (activation_target) |act_target| {
            if (hasLegacyPreActivationBehavior(act_target)) {
                runLegacyPreActivationBehavior(act_target);
            }
        }

        // clearTargets is used in step 11 below
    }

    // Step 7: Set event's eventPhase attribute to NONE
    event.event_phase = Event.NONE;

    // Step 8: Set event's currentTarget attribute to null
    event.current_target = null;

    // Step 9: Set event's path to the empty list
    event.path.clearRetainingCapacity();

    // Step 10: Unset event's dispatch flag, stop propagation flag, and stop immediate propagation flag
    event.dispatch_flag = false;
    event.stop_propagation_flag = false;
    event.stop_immediate_propagation_flag = false;

    // Step 11: If clearTargets is true, clear targets
    if (clear_targets) {
        event.target = null;
        event.related_target = null;
        event.touch_target_list.clearRetainingCapacity();
    }

    // Step 12: If activationTarget is non-null, run activation behavior
    if (activation_target) |act_target| {
        // Step 12.1: If event's canceled flag is unset, run activationTarget's activation behavior
        if (!event.canceled_flag) {
            runActivationBehavior(act_target, event);
        }
        // Step 12.2: Otherwise, if activationTarget has legacy-canceled-activation behavior, run it
        else if (hasLegacyCanceledActivationBehavior(act_target)) {
            runLegacyCanceledActivationBehavior(act_target);
        }
    }

    // Step 13: Return false if event's canceled flag is set; otherwise true
    return !event.canceled_flag;
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
fn retarget(a: ?*EventTarget, b: *EventTarget) ?*EventTarget {
    var current_a = a;

    while (current_a) |a_target| {
        // Step 1: Check if we should return A

        // Step 1.1: If A is not a node, return A
        // Non-Node EventTargets: EventTarget, AbortSignal
        if (a_target.type_tag == .EventTarget or a_target.type_tag == .AbortSignal) {
            return a_target;
        }

        // A is a node - cast it
        const a_node: *Node = @ptrCast(@alignCast(a_target));

        // Step 1.2: If A's root is not a shadow root, return A
        const a_root = a_node.call_getRootNode(.{});
        const NodeTypeTag = @import("node").NodeTypeTag;
        if (a_root.base.type_tag != NodeTypeTag.ShadowRoot) {
            return a_target;
        }

        // A's root is a shadow root
        const a_shadow_root: *ShadowRoot = @ptrCast(@alignCast(a_root));

        // Step 1.3: If B is a node and A's root is a shadow-including inclusive ancestor of B
        if (b.type_tag != .EventTarget and b.type_tag != .AbortSignal) {
            const b_node: *Node = @ptrCast(@alignCast(b));
            const a_root_node: *Node = @ptrCast(@alignCast(a_root));

            // Check if A's root is shadow-including inclusive ancestor of B
            const tree_helpers = @import("tree_helpers.zig");
            if (tree_helpers.isShadowIncludingInclusiveAncestor(a_root_node, b_node)) {
                return a_target;
            }
        }

        // Step 2: Set A to A's root's host
        const host_element = a_shadow_root.host_element;
        current_a = @ptrCast(&host_element.base);
    }

    // If A becomes null, return null
    return null;
}

/// Check if ancestor is a shadow-including inclusive ancestor of node
/// DOM §4.2.2.4: A is a shadow-including inclusive ancestor of B if:
/// - A is an inclusive ancestor of B, OR
/// - B's root is a shadow root and A is a shadow-including inclusive ancestor of B's host
fn isShadowIncludingInclusiveAncestor(ancestor: *Node, node: *Node) bool {
    // Check if ancestor is an inclusive ancestor of node (tree.zig)
    const tree = @import("dom").tree;
    if (tree.isInclusiveAncestor(ancestor, node)) {
        return true;
    }

    // Check if node's root is a shadow root
    const node_root = node.call_getRootNode(.{});
    const NodeTypeTag = @import("node").NodeTypeTag;
    if (node_root.base.type_tag == NodeTypeTag.ShadowRoot) {
        // Get shadow root's host
        const shadow: *ShadowRoot = @ptrCast(@alignCast(node_root));
        const host_element = shadow.host_element;
        const host_node: *Node = @ptrCast(@alignCast(&host_element.base));

        // Recursively check if ancestor is shadow-including inclusive ancestor of host
        return isShadowIncludingInclusiveAncestor(ancestor, host_node);
    }

    return false;
}

/// DOM §2.9 - get the parent
/// Each EventTarget has an associated get the parent algorithm
/// DOM §2.9 - get the parent
/// Each EventTarget has an associated "get the parent" algorithm.
/// Nodes, shadow roots, and documents override this algorithm.
fn getTheParent(target: *EventTarget, event: *Event) ?*EventTarget {
    // Per spec (DOM §2.9): Each EventTarget has a "get the parent" algorithm
    // For Node: return parent, unless event.composed is false and node is a shadow root, then return null
    // For ShadowRoot: if event.composed is false, return null; otherwise return host

    // Check if this is a Node
    if (target.type_tag != .EventTarget and target.type_tag != .AbortSignal) {
        const node: *Node = @ptrCast(@alignCast(target));

        // Check if this is a ShadowRoot
        const NodeTypeTag = @import("node").NodeTypeTag;
        if (node.base.type_tag == NodeTypeTag.ShadowRoot) {
            // This is a ShadowRoot
            // If event.composed is false, return null (don't cross shadow boundary)
            if (!event.composed) {
                return null;
            }

            // If composed is true, return the host
            const shadow: *ShadowRoot = @ptrCast(@alignCast(node));
            const host_element = shadow.host_element;
            return @ptrCast(@alignCast(&host_element.base));
        }

        // Regular Node - check if assigned to a slot
        // Per spec: If node is assigned, return node's assigned slot
        if (node.base.type_tag == .Element) {
            const element: *const Element = @ptrCast(@alignCast(node));
            if (element.assigned_slot) |slot| {
                // Return the assigned slot as EventTarget
                return @ptrCast(@alignCast(slot));
            }
        }
        // TODO: Text nodes can also be assigned to slots

        // Return parent_node
        if (node.parent_node) |parent| {
            return &parent.base;
        }
    }

    return null;
}

/// DOM §2.9 - invoke
/// Invoke event listeners for a given struct in the event path
fn invoke(
    event: *Event,
    path_struct: EventPathItem,
    phase: []const u8,
    legacy_output_did_listeners_throw_flag: ?*bool,
) !void {
    // Step 1: Set event's target to the shadow-adjusted target of the last struct
    // in event's path that is either this struct or preceding it, whose shadow-adjusted target is non-null
    for (event.path.items) |item| {
        if (item.shadow_adjusted_target) |target| {
            if (@intFromPtr(&item) <= @intFromPtr(&path_struct)) {
                event.target = target;
            }
        }
    }

    // Step 2: Set event's relatedTarget to struct's relatedTarget
    event.related_target = path_struct.related_target;

    // Step 3: Set event's touch target list to struct's touch target list
    event.touch_target_list.clearRetainingCapacity();
    try event.touch_target_list.appendSlice(path_struct.touch_target_list.items);

    // Step 4: If event's stop propagation flag is set, return
    if (event.stop_propagation_flag) return;

    // Step 5: Initialize event's currentTarget attribute to struct's invocation target
    event.current_target = path_struct.invocation_target;

    // Step 6: Let listeners be a clone of event's currentTarget's event listener list
    // Clone to avoid issues with listeners added/removed during dispatch
    const current_target = event.current_target.?;

    var listeners = infra.List(EventListener).init(event.allocator);
    defer listeners.deinit();

    // Get the event_listener_list from EventTarget
    if (current_target.event_listener_list) |list| {
        try listeners.appendSlice(list.items());
    }

    // Step 7: Let invocationTargetInShadowTree be struct's invocation-target-in-shadow-tree
    const invocation_target_in_shadow_tree = path_struct.invocation_target_in_shadow_tree;

    // Step 8: Let found be the result of running inner invoke
    const found = try innerInvoke(
        event,
        listeners.items(),
        phase,
        invocation_target_in_shadow_tree,
        legacy_output_did_listeners_throw_flag,
    );

    // Step 9: If found is false and event's isTrusted attribute is true, handle legacy event types
    if (!found and event.is_trusted) {
        // Step 9.1: Let originalEventType be event's type attribute value
        const original_event_type = event.event_type;

        // Step 9.2: Check for legacy event type mappings
        const legacy_type = getLegacyEventType(event.event_type);
        if (legacy_type) |legacy| {
            // Step 9.3: Inner invoke with legacy type
            event.event_type = legacy;
            _ = try innerInvoke(
                event,
                listeners.items,
                phase,
                invocation_target_in_shadow_tree,
                legacy_output_did_listeners_throw_flag,
            );

            // Step 9.4: Set event's type back to originalEventType
            event.event_type = original_event_type;
        }
    }
}

/// INTEGRATION POINT: Callback Invocation
/// Stub function for invoking event listener callbacks.
/// Replace this with actual JavaScript engine integration.
///
/// Expected behavior:
/// - Call callback.handleEvent(event)
/// - Bind "this" correctly (usually the event's currentTarget)
/// - Catch and report exceptions
/// - Set legacy_flag to true if exception is thrown
/// - Return true if callback was invoked successfully
fn invokeCallback(
    callback: ?webidl.JSValue,
    event: *Event,
    legacy_flag: ?*bool,
) bool {
    _ = event;
    _ = legacy_flag;

    if (callback) |_| {
        // NOTE: Actual callback invocation requires JS runtime integration
        // JS engine would:
        // 1. Resolve callback to actual function
        // 2. Call function with event as parameter
        // 3. Handle exceptions and report them
        // 4. Set legacy_flag.* = true on exception
        return true; // Placeholder: assume success
    }

    return false;
}

/// DOM §2.9 - inner invoke
/// Inner invoke algorithm that actually calls the listeners
fn innerInvoke(
    event: *Event,
    listeners: []const EventListener,
    phase: []const u8,
    invocation_target_in_shadow_tree: bool,
    legacy_output_did_listeners_throw_flag: ?*bool,
) !bool {
    // Step 1: Let found be false
    var found = false;

    // Step 2: For each listener of listeners, whose removed is false
    for (listeners) |listener| {
        if (listener.removed) continue;

        // Step 2.1: If event's type attribute value is not listener's type, then continue
        if (!std.mem.eql(u8, event.event_type, listener.type)) continue;

        // Step 2.2: Set found to true
        found = true;

        // Step 2.3: If phase is "capturing" and listener's capture is false, then continue
        if (std.mem.eql(u8, phase, "capturing") and !listener.capture) continue;

        // Step 2.4: If phase is "bubbling" and listener's capture is true, then continue
        if (std.mem.eql(u8, phase, "bubbling") and listener.capture) continue;

        // Step 2.5: If listener's once is true, then remove the event listener
        // Spec: "If listener's once is true, then remove an event listener given
        // event's currentTarget attribute value and listener."
        // https://dom.spec.whatwg.org/#concept-event-listener-inner-invoke
        if (listener.once) {
            const current_target = event.current_target orelse continue;
            // Remove from the actual event listener list (not the cloned iteration list)
            // This is safe because we're iterating over a clone, not the original list
            current_target.removeAnEventListener(listener);
        }

        // Step 2.6-8: Handle global and currentEvent (Window-specific)
        // TODO: Implement when Window object is available
        _ = invocation_target_in_shadow_tree;

        // Step 2.9: If listener's passive is true, set event's in passive listener flag
        if (listener.passive orelse false) {
            event.in_passive_listener_flag = true;
        }

        // Step 2.10: Record timing info (performance API integration)
        // TODO: Implement when Performance API is available

        // Step 2.11: Call the listener's callback
        // INTEGRATION POINT: Callback Invocation
        //
        // To integrate with a JavaScript engine or callback system:
        // 1. Check if listener.callback is non-null
        // 2. Call callback.handleEvent(event) with proper "this" binding
        // 3. Catch any exceptions thrown by the callback
        // 4. Report exceptions via reportException()
        // 5. Set legacyOutputDidListenersThrowFlag to true if exception thrown
        //
        // Example integration:
        // if (listener.callback) |callback| {
        //     const result = callback.handleEvent(event);
        //     if (result) |_| {
        //         // Success
        //     } else |err| {
        //         reportException(err);
        //         if (legacy_output_did_listeners_throw_flag) |flag| {
        //             flag.* = true;
        //         }
        //     }
        // }
        const callback_invoked = invokeCallback(listener.callback, event, legacy_output_did_listeners_throw_flag);
        _ = callback_invoked;

        // Step 2.12: Unset event's in passive listener flag
        event.in_passive_listener_flag = false;

        // Step 2.13: Reset currentEvent (Window-specific)
        // TODO: Implement when Window object is available

        // Step 2.14: If event's stop immediate propagation flag is set, then break
        if (event.stop_immediate_propagation_flag) break;
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
/// Each EventTarget object can have an associated activation behavior algorithm.
/// The activation behavior algorithm is passed an event, as indicated in the dispatch algorithm.
///
/// TODO: This is a stub implementation. Activation behavior is defined per EventTarget type.
/// HTML elements like <a>, <button>, <input>, <label>, <summary> have activation behavior.
/// For example:
/// - <a> navigates to href
/// - <button> submits form or fires synthetic click
/// - <input type="checkbox"> toggles checked state
///
/// Integration required:
/// - HTML element implementations must register activation behavior
/// - Custom elements may define activation behavior
/// - This function should check EventTarget's activation_behavior field (if added)
fn hasActivationBehavior(target: *EventTarget) bool {
    _ = target;
    // TODO: Check if target has activation behavior
    // For now, return false (no HTML elements implemented yet)
    return false;
}

/// DOM §2.9 - Run activation behavior
/// Run the activation behavior algorithm for the given EventTarget with the event.
///
/// TODO: This is a stub implementation. Replace with actual activation behavior execution.
/// The activation behavior should be stored on the EventTarget and invoked here.
fn runActivationBehavior(target: *EventTarget, event: *Event) void {
    _ = target;
    _ = event;
    // TODO: Execute target's activation behavior algorithm
    // Examples:
    // - HTMLAnchorElement: navigate to href
    // - HTMLButtonElement: submit form or fire synthetic click
    // - HTMLInputElement: toggle checked state, etc.
}

/// DOM §2.9 - Check if EventTarget has legacy-pre-activation behavior
/// Each EventTarget object that has activation behavior can additionally have both
/// a legacy-pre-activation behavior algorithm and a legacy-canceled-activation behavior algorithm.
///
/// TODO: This is a stub implementation. Legacy pre-activation behavior is rare.
/// Example: <input type="checkbox"> sets indeterminate to false before activation
fn hasLegacyPreActivationBehavior(target: *EventTarget) bool {
    _ = target;
    // TODO: Check if target has legacy-pre-activation behavior
    return false;
}

/// DOM §2.9 - Run legacy-pre-activation behavior
/// Run the legacy-pre-activation behavior algorithm for the given EventTarget.
///
/// TODO: This is a stub implementation. Replace with actual legacy-pre-activation behavior.
fn runLegacyPreActivationBehavior(target: *EventTarget) void {
    _ = target;
    // TODO: Execute target's legacy-pre-activation behavior algorithm
}

/// DOM §2.9 - Check if EventTarget has legacy-canceled-activation behavior
/// Each EventTarget object that has activation behavior can additionally have both
/// a legacy-pre-activation behavior algorithm and a legacy-canceled-activation behavior algorithm.
///
/// TODO: This is a stub implementation. Legacy canceled-activation behavior is rare.
/// Example: <input type="checkbox"> reverts checked state if activation was canceled
fn hasLegacyCanceledActivationBehavior(target: *EventTarget) bool {
    _ = target;
    // TODO: Check if target has legacy-canceled-activation behavior
    return false;
}

/// DOM §2.9 - Run legacy-canceled-activation behavior
/// Run the legacy-canceled-activation behavior algorithm for the given EventTarget.
///
/// TODO: This is a stub implementation. Replace with actual legacy-canceled-activation behavior.
fn runLegacyCanceledActivationBehavior(target: *EventTarget) void {
    _ = target;
    // TODO: Execute target's legacy-canceled-activation behavior algorithm
}
