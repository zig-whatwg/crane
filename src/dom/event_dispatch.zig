// DOM Standard: Event Dispatch Algorithms (§2.9)
// https://dom.spec.whatwg.org/#dispatching-events

const std = @import("std");
const Event = @import("../webidl/src/dom/Event.zig").Event;
const EventTarget = @import("../webidl/src/dom/EventTarget.zig").EventTarget;
const EventPathItem = Event.EventPathItem;

/// DOM §2.9.1 - append to an event path
/// To append to an event path, given an event, invocationTarget, shadowAdjustedTarget,
/// relatedTarget, touchTargets, and a slot-in-closed-tree, run these steps:
pub fn appendToEventPath(
    event: *Event,
    invocation_target: *EventTarget,
    shadow_adjusted_target: ?*EventTarget,
    related_target: ?*EventTarget,
    touch_targets: std.ArrayList(*EventTarget),
    slot_in_closed_tree: bool,
) !void {
    // Step 1: Let invocationTargetInShadowTree be false
    // Step 2: If invocationTarget is a node and its root is a shadow root,
    // then set invocationTargetInShadowTree to true
    // TODO: Check if invocationTarget is a node and its root is a shadow root
    // For now, assume false (no shadow DOM support yet)
    const invocation_target_in_shadow_tree = false;

    // Step 3: Let root-of-closed-tree be false
    const root_of_closed_tree = false;
    // TODO: Check if invocationTarget is a shadow root whose mode is "closed"

    // Step 4: If invocationTarget is a shadow root whose mode is "closed",
    // then set root-of-closed-tree to true
    // TODO: Check if invocationTarget is a closed shadow root

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
        // TODO: Get target's associated Document
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
        var touch_targets = std.ArrayList(*EventTarget).init(event.allocator);

        // Step 6.2: For each touchTarget of event's touch target list,
        // append the result of retargeting touchTarget against target to touchTargets
        for (event.touch_target_list.items) |touch_target| {
            const retargeted = retarget(touch_target, target);
            if (retargeted) |t| {
                try touch_targets.append(t);
            }
        }

        // Step 6.3: Append to an event path
        try appendToEventPath(event, target, target_override, related_target, touch_targets, false);

        // Step 6.4: Let isActivationEvent be true if event is MouseEvent and type is "click"
        // TODO: Check if event is MouseEvent with type "click"
        const is_activation_event = false;

        // Step 6.5: If isActivationEvent and target has activation behavior, set activationTarget
        if (is_activation_event) {
            // TODO: Check if target has activation behavior
            activation_target = target;
        }

        // Step 6.6: Let slottable be target, if target is a slottable and is assigned
        // TODO: Shadow DOM - check if target is a slottable and is assigned
        // For now: No shadow DOM support, so slottable is always null
        const slottable: ?*EventTarget = null;

        // Step 6.7: Let slot-in-closed-tree be false
        var slot_in_closed_tree = false;

        // Step 6.8: Let parent be the result of invoking target's get the parent with event
        var parent = getTheParent(target, event);

        // Step 6.9: While parent is non-null
        while (parent) |p| {
            // Step 6.9.1-2: Handle slottable
            if (slottable != null) {
                // Assert: parent is a slot
                // Set slottable to null
                // If parent's root is a shadow root whose mode is "closed", set slot-in-closed-tree to true
                // (Shadow DOM not implemented yet, so this branch never executes)
            }

            // Step 6.9.3: If parent is a slottable and is assigned, set slottable to parent
            // (Shadow DOM not implemented yet)

            // Step 6.9.4: Let relatedTarget be result of retargeting event's relatedTarget against parent
            const parent_related_target = retarget(event.related_target, p);

            // Step 6.9.5: Let touchTargets be a new list
            var parent_touch_targets = std.ArrayList(*EventTarget).init(event.allocator);
            defer parent_touch_targets.deinit();

            // Step 6.9.6: For each touchTarget of event's touch target list,
            // append the result of retargeting touchTarget against parent to touchTargets
            for (event.touch_target_list.items) |touch_target| {
                const retargeted_touch = retarget(touch_target, p);
                if (retargeted_touch) |t| {
                    try parent_touch_targets.append(t);
                }
            }

            // Step 6.9.7: If parent is a Window object, or parent is a node and target's root
            // is a shadow-including inclusive ancestor of parent
            // TODO: Check Window and shadow tree conditions
            // For now, assume this condition is true (append to path)
            try appendToEventPath(event, p, null, parent_related_target, parent_touch_targets, slot_in_closed_tree);

            // Step 6.9.8: Otherwise, if parent is relatedTarget, set parent to null
            // Step 6.9.9: Otherwise, append to event path with different parameters
            // (Simplified for now - always append in step 6.9.7)

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

        // Step 6.15: Activation target will be used in step 12 below
        // (Not fully implemented yet - requires activation behavior support)

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
    // TODO: Implement activation behavior

    // Step 13: Return false if event's canceled flag is set; otherwise true
    return !event.canceled_flag;
}

/// DOM §2.9 - retarget
/// To retarget an object A against an object B, run these steps:
fn retarget(a: ?*EventTarget, b: *EventTarget) ?*EventTarget {
    // Simplified: For now, just return a
    // Full algorithm involves shadow tree traversal
    _ = b;
    return a;
}

/// DOM §2.9 - get the parent
/// Each EventTarget has an associated get the parent algorithm
/// DOM §2.9 - get the parent
/// Each EventTarget has an associated "get the parent" algorithm.
/// Nodes, shadow roots, and documents override this algorithm.
fn getTheParent(target: *EventTarget, event: *Event) ?*EventTarget {
    const NodeBase = @import("../webidl/generated/dom/node.zig").NodeBase;
    const EventTargetBase = @import("../webidl/generated/dom/event_target.zig").EventTargetBase;

    // Cast EventTarget to EventTargetBase to access polymorphic features
    const target_base = @as(*EventTargetBase, @ptrCast(target));

    // Try to cast to Node (most common case)
    // Node's get the parent: return node's assigned slot if assigned, otherwise parent
    if (target_base.tryCast(NodeBase)) |node_base| {
        // Check if node is assigned to a slot (Shadow DOM feature)
        // Node has assigned_slot field from Slottable mixin
        if (@hasField(@TypeOf(node_base.*), "assigned_slot")) {
            if (@field(node_base, "assigned_slot")) |slot| {
                return @ptrCast(slot);
            }
        }

        // Otherwise return parent_node
        if (node_base.parent_node) |parent| {
            return @ptrCast(parent);
        }
        return null;
    }

    // Try to cast to ShadowRoot
    // ShadowRoot's get the parent: return null if event's composed flag is unset
    // and shadow root is the root of event's path's first struct's invocation target,
    // otherwise return shadow root's host
    const ShadowRootBase = @import("../webidl/generated/dom/ShadowRoot.zig").ShadowRootBase;
    if (target_base.tryCast(ShadowRootBase)) |shadow_root| {
        // Check if event's composed flag is unset
        if (!event.composed) {
            // Check if shadow root is the root of event's path's first struct's invocation target
            if (event.path.items.len > 0) {
                const first_struct = event.path.items[0];
                const invocation_target = first_struct.invocation_target;

                // Get the root of the invocation target
                // For now, simplified check: if invocation target is the shadow root, return null
                if (@intFromPtr(invocation_target) == @intFromPtr(target)) {
                    return null;
                }
            }
        }

        // Otherwise return shadow root's host
        return @ptrCast(shadow_root.host_element);
    }

    // Try to cast to Document
    // Document's get the parent: return null if event type is "load" or
    // document has no browsing context, otherwise return document's relevant global object
    const DocumentBase = @import("../webidl/generated/dom/document.zig").DocumentBase;
    if (target_base.tryCast(DocumentBase)) |_| {
        // Check if event type is "load"
        if (std.mem.eql(u8, event.event_type, "load")) {
            return null;
        }

        // TODO: Check if document has browsing context
        // For now, return null (no browsing context / global object implementation yet)
        return null;
    }

    // Default: return null (as per spec)
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
    const EventListener = @import("../webidl/generated/dom/EventTarget.zig").EventListener;
    const EventTargetBase = @import("../webidl/generated/dom/EventTarget.zig").EventTargetBase;

    var listeners = std.ArrayList(EventListener).init(event.allocator);
    defer listeners.deinit();

    // Get the event_listener_list from EventTarget
    // Must cast to EventTargetBase to access the event_listener_list field
    // (All EventTargets have EventTargetBase as their first field or embedded via inheritance)
    const target_base = @as(*EventTargetBase, @ptrCast(current_target));
    if (target_base.event_listener_list) |list| {
        try listeners.appendSlice(list.items);
    }

    // Step 7: Let invocationTargetInShadowTree be struct's invocation-target-in-shadow-tree
    const invocation_target_in_shadow_tree = path_struct.invocation_target_in_shadow_tree;

    // Step 8: Let found be the result of running inner invoke
    const found = try innerInvoke(
        event,
        listeners.items,
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

/// DOM §2.9 - inner invoke
/// Inner invoke algorithm that actually calls the listeners
fn innerInvoke(
    event: *Event,
    listeners: []const @import("../webidl/generated/dom/EventTarget.zig").EventListener,
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
        if (listener.once) {
            // TODO: Implement removeEventListener
            // For now, we can't remove during iteration - mark as removed
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
        // TODO: Implement actual callback invocation
        // For now, this is a placeholder - actual implementation requires:
        // - JavaScript engine integration for callback invocation
        // - Proper "this" binding
        // - Exception handling and reporting
        _ = listener.callback; // Would invoke callback.handleEvent(event) here

        // If an exception is thrown:
        // - Report exception
        // - Set legacyOutputDidListenersThrowFlag if given
        _ = legacy_output_did_listeners_throw_flag; // Would be set to true if exception thrown

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
