//! HTML 6.10 "Close requests and close watchers": the algorithms over each
//! Window's close watcher manager (dom.close_watcher_manager holds the data
//! and Window's accessor).
//!
//! Who calls what:
//!   * a CloseWatcher object (its internal close watcher), an element's
//!     popover (HTML 6.12 show step 15.10, hide step 21) and a dialog
//!     (HTML 4.11.4) - `establish`, `requestClose`, `close`, `destroy`,
//!     `isActive`, each naming its watcher by its kind and its owner;
//!   * the activation notification (6.4.2 step 5.2) - `notifyUserActivation`;
//!   * the user agent's close request: an Escape keydown that was not
//!     canceled (user_input.keyDown) - `closeRequestSteps`; a host's close
//!     request with no event (a back gesture) - `requestCloseFromHost`.
//!
//! Every watcher keeps its owner and is freed only by its last reference
//! (dom.close_watcher_manager, "OWNERSHIP"): each algorithm that runs a
//! watcher's actions holds one across them, and re-reads whether the
//! watcher's Window still has its manager before touching it again - a
//! cancel action's script can remove the frame the Window is in (Blink's
//! CloseWatcher::requestClose re-checks DomWindow() after dispatch).
//!
//! Spec: https://html.spec.whatwg.org/multipage/interaction.html#close-requests-and-close-watchers

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const user_activation = @import("user_activation.zig");

const Instance = runtime.Instance;
const manager_mod = dom.close_watcher_manager;
pub const Kind = manager_mod.Kind;
pub const Actions = manager_mod.Actions;
pub const Manager = manager_mod.Manager;
const CloseWatcher = manager_mod.CloseWatcher;

const log = std.log.scoped(.close_watchers);

/// The Window `owner`'s relevant realm belongs to - its "relevant global
/// object" - or null outside a Window (a worker, a test realm).
pub fn relevantWindow(owner: *Instance) ?*Instance {
    return user_activation.windowOfRealm(owner.ctx);
}

/// Whether `window`'s associated Document is fully active.
fn associatedDocumentFullyActive(window: *Instance) bool {
    const document = interfaces.Window.get_document(window) catch return false;
    return dom.document_activity.fullyActive(document, runtime.SlabAllocator.generationOf(document));
}

/// `window` still has `manager`: a cancel action's script may have ended the
/// Window. Read through the Window's slab generation (the Instance's memory
/// is its Browser's until the Browser ends) before its state - a teardown
/// net for that one case, never the behaviour.
fn stillManaged(window: *Instance, generation: u64, manager: *Manager) bool {
    if (runtime.SlabAllocator.generationOf(window) != generation) return false;
    return manager_mod.of(window) == manager;
}

/// HTML "establish a close watcher" given `window`, with `owner`'s actions:
/// the watcher of `kind` for `owner` (one at most - an earlier one is
/// destroyed first).
pub fn establish(window: *Instance, kind: Kind, owner: *Instance, actions: *const Actions) !void {
    const manager = manager_mod.of(window) orelse return error.NotSupported;
    // 1. Assert: window's associated Document is fully active. (Each caller
    // checked it: the CloseWatcher constructor throws, a popover or dialog
    // is shown only in a fully active document.)
    if (manager.find(kind, owner)) |previous| manager.remove(previous);
    // 2. Let closeWatcher be a new close watcher, with window, cancelAction,
    // closeAction, is running cancel action false and getEnabledState.
    const watcher = try manager.create(kind, owner, actions);
    // 3-5. Append « closeWatcher » to the manager's groups while their size
    // is less than the allowed number of groups; otherwise append it to the
    // last group.
    manager.add(watcher) catch |err| {
        watcher.release();
        return err;
    };
    // 6. Set manager's next user interaction allows a new group to true.
    manager.next_user_interaction_allows_a_new_group = true;
    // 7. Return closeWatcher: its creator names it by kind and owner.
}

/// Whether the close watcher of `kind` for `owner` "is active".
pub fn isActive(window: *Instance, kind: Kind, owner: *Instance) bool {
    const manager = manager_mod.of(window) orelse return false;
    return manager.find(kind, owner) != null;
}

/// HTML "request to close" the close watcher of `kind` for `owner`, with
/// `require_history_action_activation`. A watcher that does not exist is not
/// active: true.
pub fn requestClose(window: *Instance, kind: Kind, owner: *Instance, require_history_action_activation: bool) bool {
    const manager = manager_mod.of(window) orelse return true;
    const watcher = manager.find(kind, owner) orelse return true;
    return requestCloseWatcher(window, watcher, require_history_action_activation);
}

/// HTML "close" the close watcher of `kind` for `owner`.
pub fn close(window: *Instance, kind: Kind, owner: *Instance) void {
    const manager = manager_mod.of(window) orelse return;
    const watcher = manager.find(kind, owner) orelse return;
    closeWatcherSteps(watcher);
}

/// HTML "destroy" the close watcher of `kind` for `owner`.
pub fn destroy(window: *Instance, kind: Kind, owner: *Instance) void {
    const manager = manager_mod.of(window) orelse return;
    const watcher = manager.find(kind, owner) orelse return;
    // 1-3. Remove closeWatcher from every group of its window's manager,
    // then every empty group.
    manager.remove(watcher);
}

/// HTML "request to close" `watcher`.
fn requestCloseWatcher(window: *Instance, watcher: *CloseWatcher, require_history_action_activation: bool) bool {
    // 1. If closeWatcher is not active, then return true.
    const manager = watcher.manager orelse return true;
    // The watcher keeps its owner; null only after a teardown freed it.
    const owner = watcher.owner.get() orelse return true;
    // 2. If the result of running closeWatcher's get enabled state is false,
    // then return true.
    if (!watcher.actions.enabled(owner)) return true;
    // 3. If closeWatcher's is running cancel action is true, then return
    // true.
    if (watcher.is_running_cancel_action) return true;
    // 4. Let window be closeWatcher's window. 5. If window's associated
    // Document is not fully active, then return true.
    if (!associatedDocumentFullyActive(window)) return true;
    // 6. Let canPreventClose be true if requireHistoryActionActivation is
    // false, or if window's close watcher manager's groups' size is less
    // than its allowed number of groups, and window has history-action
    // activation; otherwise false.
    const can_prevent_close = !require_history_action_activation or
        (manager.groups.items.len < manager.allowed_number_of_groups and user_activation.hasHistoryActionActivation(window));
    // The cancel action runs script: this algorithm holds the watcher, and
    // looks again at its Window afterwards.
    watcher.retain();
    defer watcher.release();
    const window_generation = runtime.SlabAllocator.generationOf(window);
    // 7. Set closeWatcher's is running cancel action to true.
    watcher.is_running_cancel_action = true;
    // 8. Let shouldContinue be the result of running closeWatcher's cancel
    // action given canPreventClose.
    const should_continue = watcher.actions.cancel(owner, can_prevent_close);
    // 9. Set closeWatcher's is running cancel action to false.
    watcher.is_running_cancel_action = false;
    // 10. If shouldContinue is false:
    if (!should_continue) {
        // 10.1. Assert: canPreventClose is true. (A cancel action given
        // false always returns true.)
        std.debug.assert(can_prevent_close);
        // 10.2. Consume history-action user activation given window - while
        // the Window still exists.
        if (stillManaged(window, window_generation, manager)) user_activation.consumeHistoryAction(window);
        // 10.3. Return false.
        return false;
    }
    // 11. Close closeWatcher. (Its step 1 sees a watcher the script
    // destroyed, or whose Window ended, as not active.)
    closeWatcherSteps(watcher);
    // 12. Return true.
    return true;
}

/// HTML "close" `watcher`.
fn closeWatcherSteps(watcher: *CloseWatcher) void {
    // 1. If closeWatcher is not active, then return.
    const manager = watcher.manager orelse return;
    const window = manager.window orelse return;
    const owner = watcher.owner.get() orelse return;
    // 2. If the result of running closeWatcher's get enabled state is false,
    // then return.
    if (!watcher.actions.enabled(owner)) return;
    // 3. If closeWatcher's window's associated Document is not fully
    // active, then return.
    if (!associatedDocumentFullyActive(window)) return;
    // The close action runs after the watcher left its manager: hold it.
    watcher.retain();
    defer watcher.release();
    // 4. Destroy closeWatcher.
    manager.remove(watcher);
    // 5. Run closeWatcher's close action.
    watcher.actions.close(owner);
}

/// HTML "process close watchers" given `window`: whether a close watcher was
/// processed.
pub fn process(window: *Instance) bool {
    const manager = manager_mod.of(window) orelse return false;
    const window_generation = runtime.SlabAllocator.generationOf(window);
    // 1. Let processedACloseWatcher be false.
    var processed = false;
    // 2. If window's close watcher manager's groups is not empty:
    if (manager.groups.items.len != 0) {
        // 2.1. Let group be the last item in the groups. Each request runs
        // script, which can destroy watchers and establish new ones: the
        // group as it is now is what is walked, each watcher held.
        const live = manager.groups.items[manager.groups.items.len - 1].items;
        const group = manager.allocator.dupe(*CloseWatcher, live) catch |err| {
            log.warn("close watchers not processed: {}", .{err});
            return false;
        };
        defer manager.allocator.free(group);
        for (group) |watcher| watcher.retain();
        defer for (group) |watcher| watcher.release();
        // 2.2. For each closeWatcher of group, in reverse order:
        var i = group.len;
        while (i != 0) {
            i -= 1;
            const watcher = group[i];
            // 2.2.1. If the result of running closeWatcher's get enabled
            // state is true, set processedACloseWatcher to true. (A watcher
            // destroyed by an earlier one's script is not asked.)
            if (watcher.isActive()) if (watcher.owner.get()) |owner| {
                if (watcher.actions.enabled(owner)) processed = true;
            };
            // 2.2.2. Let shouldProceed be the result of requesting to close
            // closeWatcher with true.
            const should_proceed = requestCloseWatcher(window, watcher, true);
            // 2.2.3. If shouldProceed is false, then break.
            if (!should_proceed) break;
            if (!stillManaged(window, window_generation, manager)) return processed;
        }
    }
    if (!stillManaged(window, window_generation, manager)) return processed;
    // 3. If window's close watcher manager's allowed number of groups is
    // greater than 1, decrement it by 1.
    if (manager.allowed_number_of_groups > 1) manager.allowed_number_of_groups -= 1;
    // 4. Return processedACloseWatcher.
    return processed;
}

/// HTML "notify the close watcher manager about user activation" given
/// `window`.
pub fn notifyUserActivation(window: *Instance) void {
    // 1. Let manager be window's close watcher manager.
    const manager = manager_mod.of(window) orelse return;
    // 2. If manager's next user interaction allows a new group is true, then
    // increment manager's allowed number of groups.
    if (manager.next_user_interaction_allows_a_new_group) manager.allowed_number_of_groups += 1;
    // 3. Set manager's next user interaction allows a new group to false.
    manager.next_user_interaction_allows_a_new_group = false;
}

/// HTML 6.10.1 "close request steps" 1 and 5-9, for a close request
/// targeted at `document` whose relevant event - the single keydown of an
/// Escape key, fired by the caller as step 3 - was not canceled (step 5
/// returned for the caller). Whether something was closed (step 8); false
/// is step 9's "alternative processing", which Crane does not do.
pub fn closeRequestSteps(document: *Instance) bool {
    // 6. If document is not fully active, then return. (A keydown listener
    // may have made it so.)
    if (!dom.document_activity.fullyActive(document, runtime.SlabAllocator.generationOf(document))) return false;
    // 7. Let closedSomething be the result of processing close watchers on
    // document's relevant global object.
    const window = (interfaces.Document.get_defaultView(document) catch null) orelse return false;
    // 8. If closedSomething is true, then return. 9. Otherwise there was
    // nothing watching for a close request.
    return process(window);
}

/// The close request steps' step 1, for a close request targeted at
/// `document`, before any event is fired: whether the request ends there.
/// "If document's fullscreen element is not null: fully exit fullscreen
/// given document's node navigable's top-level traversable's active
/// document, and return." Crane makes no element fullscreen
/// (Document.fullscreen_element is never set: there is no display mode to
/// enter), so there is nothing to exit; a fullscreen element, should one
/// ever be set, ends the request as the step says, and exiting it is the
/// fullscreen owner's TODO (no "fully exit fullscreen" algorithm exists).
pub fn closeRequestEndsInFullscreen(document: *Instance) bool {
    const element = interfaces.Document.get_fullscreenElement(document) catch return false;
    return element != null;
}

/// A close request with no event (a back gesture, an assistive technology's
/// dismiss), from the host, targeted at `document`: HTML 6.10.1 "queue a
/// global task on the user interaction task source given document's
/// relevant global object to perform the close request steps", with no
/// relevant event (steps 3-5 fire nothing). Whether the task was queued.
/// The Browser and C API entry point that calls it is the host API's
/// follow-up.
pub fn requestCloseFromHost(document: *Instance) bool {
    const Task = struct {
        /// The task keeps its document until it runs or is dropped.
        document: dom.node_holds.TaskHold = .{},
        allocator: std.mem.Allocator,

        fn run(data: ?*anyopaque) void {
            const self: *@This() = @ptrCast(@alignCast(data orelse return));
            defer self.end();
            // Null only after a teardown freed it; the loop drops a task
            // whose document can never be fully active again.
            const target = self.document.get() orelse return;
            if (target.ctx.engine_ctx == null) return;
            // Step 1, then steps 3-5 with no event: nothing fired, nothing
            // canceled.
            if (closeRequestEndsInFullscreen(target)) return;
            @import("engine").runTaskInRealm(target.ctx, steps, target) catch |err| {
                log.warn("close request not processed: {}", .{err});
            };
        }

        fn steps(data: ?*anyopaque) void {
            const target: *Instance = @ptrCast(@alignCast(data orelse return));
            _ = closeRequestSteps(target);
        }

        fn drop(data: ?*anyopaque) void {
            const self: *@This() = @ptrCast(@alignCast(data orelse return));
            self.end();
        }

        fn end(self: *@This()) void {
            self.document.release();
            self.allocator.destroy(self);
        }
    };
    const loop = document.ctx.getOptionalEventLoop() orelse return false;
    const task = document.ctx.allocator.create(Task) catch return false;
    task.* = .{ .allocator = document.ctx.allocator };
    task.document.take(document);
    // The handoff: the loop owns the task from here.
    loop.queueTask(.{
        .callback = &Task.run,
        .context = task,
        .drop = &Task.drop,
        .document = document,
        .document_generation = runtime.SlabAllocator.generationOf(document),
    });
    return true;
}
