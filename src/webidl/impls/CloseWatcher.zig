//! HTML 6.10.3 The CloseWatcher interface.
//!
//! A CloseWatcher's internal close watcher lives in its Window's close
//! watcher manager (dom.close_watcher_manager), named by (.object, this): the
//! manager owns it and keeps this object while it is active, so a watcher
//! script dropped still hears a close request (Blink's CloseWatcherStack
//! traces its watchers from LocalDOMWindow). Once destroyed it is not found,
//! which is how "is not active" reads.
//!
//! oncancel and onclose are the generated event handler attributes
//! (dom.event_handlers).
//!
//! Spec: https://html.spec.whatwg.org/multipage/interaction.html#the-closewatcher-interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dictionaries = @import("dictionaries");
const webidl = @import("webidl");
const dom = @import("dom");
const close_watchers = @import("html").close_watchers;
const CloseWatcher = interfaces.CloseWatcher;

const log = std.log.scoped(.close_watcher);

pub const State = CloseWatcher.State;

pub const InternalState = struct {};

/// The internal close watcher's algorithms, given this CloseWatcher.
const actions: close_watchers.Actions = .{
    .cancel = &cancelAction,
    .close = &closeAction,
    .enabled = &enabledState,
};

/// "cancelAction given canPreventClose being to return the result of firing
/// an event named cancel at this, with the cancelable attribute initialized
/// to canPreventClose."
fn cancelAction(watcher: *runtime.Instance, can_prevent_close: bool) bool {
    return fireEvent(watcher, "cancel", can_prevent_close);
}

/// "closeAction being to fire an event named close at this."
fn closeAction(watcher: *runtime.Instance) void {
    _ = fireEvent(watcher, "close", false);
}

/// "getEnabledState being to return true."
fn enabledState(_: *runtime.Instance) bool {
    return true;
}

/// DOM "fire an event" named `event_type` at `watcher`: whether it was not
/// canceled. An event that cannot be made is not canceled.
fn fireEvent(watcher: *runtime.Instance, comptime event_type: []const u8, cancelable: bool) bool {
    const event = interfaces.Event.call_constructor(watcher.ctx, runtime.DOMString.initInterned(event_type), webidl.Opt(dictionaries.EventInit).passed(.{ .cancelable = cancelable })) catch |err| {
        log.warn("{s} not fired at a CloseWatcher: {}", .{ event_type, err });
        return true;
    };
    const generation = runtime.SlabAllocator.generationOf(event);
    defer event.releaseIfUnwrapped(generation);
    return dom.fire_event.dispatchTrusted(watcher, event) catch true;
}

/// The Window this CloseWatcher's internal close watcher belongs to: its
/// relevant global object.
fn windowOf(instance: *runtime.Instance) ?*runtime.Instance {
    return close_watchers.relevantWindow(instance);
}

fn fullyActive(window: *runtime.Instance) bool {
    const document = interfaces.Window.get_document(window) catch return false;
    return dom.document_activity.fullyActive(document, runtime.SlabAllocator.generationOf(document));
}

/// The abort algorithm a CloseWatcher adds to its options' signal: "destroy
/// closeWatcher". It holds the watcher weakly - an inactive watcher has
/// nothing to destroy, so the signal must not keep it - and the signal frees
/// it when it runs or when the signal goes first (`drop`).
const SignalAlgorithm = struct {
    watcher: *runtime.Instance,
    generation: u64,
    allocator: std.mem.Allocator,

    fn run(ctx: *anyopaque) void {
        const self: *SignalAlgorithm = @ptrCast(@alignCast(ctx));
        defer self.allocator.destroy(self);
        // A watcher freed since (its realm ended) has no watcher to destroy.
        if (runtime.SlabAllocator.generationOf(self.watcher) != self.generation) return;
        // 3.2.1. Destroy closeWatcher.
        destroyInternal(self.watcher);
    }

    fn drop(ctx: *anyopaque) void {
        const self: *SignalAlgorithm = @ptrCast(@alignCast(ctx));
        self.allocator.destroy(self);
    }
};

/// Destroy this's internal close watcher.
fn destroyInternal(instance: *runtime.Instance) void {
    const window = windowOf(instance) orelse return;
    close_watchers.destroy(window, .object, instance);
}

/// The `new CloseWatcher(options)` constructor steps.
pub fn call_constructor(ctx: runtime.Context, options: webidl.Opt(dictionaries.CloseWatcherOptions)) !*runtime.Instance {
    // 1. If this's relevant global object's associated Document is not fully
    // active, then throw an "InvalidStateError" DOMException.
    const window = @import("html").user_activation.windowOfRealm(ctx) orelse return error.InvalidStateError;
    if (!fullyActive(window)) return error.InvalidStateError;
    const instance = try CloseWatcher.init(ctx.allocator, ctx);
    errdefer runtime.Instance.deinit(instance);
    // 2. Let closeWatcher be the result of establishing a close watcher
    // given this's relevant global object, with this's cancelAction,
    // closeAction and getEnabledState.
    try close_watchers.establish(window, .object, instance, &actions);
    errdefer close_watchers.destroy(window, .object, instance);
    // 3. If options["signal"] exists:
    const signal = if (options.wasPassed()) options.value.signal else null;
    if (signal) |abort_signal| {
        if (try interfaces.AbortSignal.get_aborted(abort_signal)) {
            // 3.1. If options["signal"] is aborted, then destroy
            // closeWatcher.
            close_watchers.destroy(window, .object, instance);
        } else {
            // 3.2. Add the following steps to options["signal"]: destroy
            // closeWatcher.
            const algorithm = try ctx.allocator.create(SignalAlgorithm);
            algorithm.* = .{ .watcher = instance, .generation = runtime.SlabAllocator.generationOf(instance), .allocator = ctx.allocator };
            dom.abort_algorithms.add(abort_signal, .{ .ctx = algorithm, .run = &SignalAlgorithm.run, .drop = &SignalAlgorithm.drop }) catch |err| {
                ctx.allocator.destroy(algorithm);
                return err;
            };
        }
    }
    // 4. Set this's internal close watcher to closeWatcher: the manager's
    // watcher of (.object, this).
    return instance;
}

/// The requestClose() method steps: request to close this's internal close
/// watcher with false.
pub fn call_requestClose(instance: *runtime.Instance) anyerror!void {
    const window = windowOf(instance) orelse return;
    _ = close_watchers.requestClose(window, .object, instance, false);
}

/// The close() method steps: close this's internal close watcher.
pub fn call_close(instance: *runtime.Instance) anyerror!void {
    const window = windowOf(instance) orelse return;
    close_watchers.close(window, .object, instance);
}

/// The destroy() method steps: destroy this's internal close watcher.
pub fn call_destroy(instance: *runtime.Instance) anyerror!void {
    destroyInternal(instance);
}
