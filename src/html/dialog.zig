//! HTML dialog algorithms shared by form submission and trusted input.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const webidl = @import("webidl");
const form_associated = @import("form_associated.zig");
const close_watchers = @import("close_watchers.zig");

/// Form submission step 11.3–5. The caller owns a passed value: closing the
/// dialog dispatches beforetoggle, which can replace the submitter's attribute.
pub fn submissionResult(allocator: std.mem.Allocator, submitter: *runtime.Instance) !webidl.Opt(runtime.DOMString) {
    if (form_associated.isInput(submitter)) {
        var buffer: [16]u8 = undefined;
        if (std.mem.eql(u8, form_associated.inputType(submitter, &buffer), "image")) {
            const coordinate = @import("forms/image_coordinate.zig").selected(submitter);
            return .passed(runtime.DOMString.initOwned(try std.fmt.allocPrint(allocator, "{d},{d}", .{ coordinate.x, coordinate.y })));
        }
    }
    if (!form_associated.isSubmitButton(submitter)) return .notPassed();
    var value = (try interfaces.Element.call_getAttribute(submitter, runtime.DOMString.initInterned("value"))) orelse return .notPassed();
    defer value.deinit(submitter.ctx.allocator);
    return .passed(try value.clone(allocator));
}

fn flatParent(node: *runtime.Instance) ?*runtime.Instance {
    if (dom.shadow_dom_algorithms.assignedSlotOf(node)) |slot| return slot;
    const parent = form_associated.parentOf(node) orelse return null;
    if (parent.stateAs(interfaces.ShadowRoot.State) != null) return interfaces.ShadowRoot.get_host(parent) catch null;
    return parent;
}

/// HTML "nearest clicked dialog", steps 3–5. Element-origin input supplies
/// an actual hit target; backdrop hit testing belongs to the layout host.
fn nearestClickedDialog(target: *runtime.Instance) ?*runtime.Instance {
    var current: ?*runtime.Instance = target;
    while (current) |node| : (current = flatParent(node)) {
        if (node.stateAs(interfaces.HTMLDialogElement.State) != null and
            form_associated.hasAttribute(node, "open")) return node;
    }
    return null;
}

/// HTML 4.11.5 "light dismiss open dialogs", called after popover dismiss
/// for trusted pointerdown/up, independently of event cancellation.
pub fn lightDismiss(target: *runtime.Instance, down: bool) void {
    const state = (dom.top_layer.ofElement(target, false) catch null) orelse return;
    // 3. An empty list preserves the target for BOTH pointer events. A later
    // press can observe it if a dialog opens after that press's pointerdown
    // (Q47, 2026-10-29). Do not move target cleanup before this return.
    if (state.lastOpenDialog() == null) return;
    const ancestor = nearestClickedDialog(target);
    if (down) {
        // 5.
        state.setDialogPointerdownTarget(ancestor);
        return;
    }
    // 6.1–3. Compare the remembered dialog even if script closed it between
    // down and up, then clear. Q37 (tmp/probes/q37/RESULT.md) kept another
    // dialog open: Firefox 158 follows this spec; Chrome 156 recomputes the
    // ancestor. The shipping browsers split, so the spec decides. A removed
    // target's lifetime marker cannot match any ancestor (Q47 addendum).
    const same_target = !state.dialog_pointerdown_target_removed and
        ancestor == state.dialog_pointerdown_target.get();
    state.setDialogPointerdownTarget(null);
    if (!same_target) return;
    // 6.4–6. Dismiss only the last opened dialog, and only in the Any state.
    const topmost = state.lastOpenDialog() orelse return;
    if (ancestor == topmost) return;
    const any = blk: {
        var closed_by = interfaces.HTMLDialogElement.get_closedBy(topmost) catch return;
        defer closed_by.deinit(topmost.ctx.allocator);
        break :blk std.mem.eql(u8, closed_by.asSlice(), "any");
    };
    if (!any) return;
    // 6.7–8. Its watcher keeps the dialog across cancel/close script.
    const window = close_watchers.relevantWindow(topmost) orelse return;
    _ = close_watchers.requestClose(window, .dialog, topmost, false);
}
