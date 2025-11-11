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
    var invocation_target_in_shadow_tree = false;

    // Step 2: If invocationTarget is a node and its root is a shadow root,
    // then set invocationTargetInShadowTree to true
    // TODO: Check if invocationTarget is a node and its root is a shadow root
    _ = invocation_target;

    // Step 3: Let root-of-closed-tree be false
    var root_of_closed_tree = false;

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
    legacy_output_did_listeners_throw_flag: ?*bool,
) !bool {
    _ = legacy_output_did_listeners_throw_flag;

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
    var clear_targets = false;

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
        // TODO: Implement slottable check
        var slottable: ?*EventTarget = null;
        _ = slottable;

        // Step 6.7: Let slot-in-closed-tree be false
        var slot_in_closed_tree = false;

        // Step 6.8: Let parent be the result of invoking target's get the parent with event
        var parent = getTheParent(target, event);

        // Step 6.9: While parent is non-null
        while (parent) |p| {
            // TODO: Implement full loop per spec (steps 6.9.1 through 6.9.10)
            // For now, stub
            _ = p;
            _ = slot_in_closed_tree;
            break;
        }

        // Steps 6.10 through 6.14: TODO - Implement full dispatch algorithm
        _ = activation_target;
        _ = clear_targets;
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
fn getTheParent(target: *EventTarget, event: *Event) ?*EventTarget {
    // TODO: Implement get the parent algorithm
    // For now, return null (no parent)
    _ = target;
    _ = event;
    return null;
}
