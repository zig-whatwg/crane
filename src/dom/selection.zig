//! A document associates its one Selection through its owner's startup hook.
//! lint-impls: hook for Selection, Range
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const process_start = @import("process_start.zig");
const fire_event = @import("fire_event.zig");

/// Each owner supplies its association or notification step; callers never
/// reach into another interface's state.
pub const Implementation = struct {
    bind_document: ?*const fn (*runtime.Instance, *runtime.Instance) void = null,
    associate_range: ?*const fn (*runtime.Instance, *runtime.Instance, bool) void = null,
    range_mutated: ?*const fn (*runtime.Instance, *runtime.Instance, bool) void = null,
    schedule_change: ?*const fn (*runtime.Instance) anyerror!void = null,
};

// process-wide: immutable Selection/Range callbacks installed once before any Browser or worker starts.
var implementation: ?Implementation = null;

/// Called by Selection.installHooks and Range.installHooks at process startup.
pub fn install(impl: Implementation) void {
    process_start.assertInstalling();
    var combined = implementation orelse Implementation{};
    if (impl.bind_document) |step| combined.bind_document = step;
    if (impl.associate_range) |step| combined.associate_range = step;
    if (impl.range_mutated) |step| combined.range_mutated = step;
    if (impl.schedule_change) |step| combined.schedule_change = step;
    implementation = combined;
}

/// Bind the wrapped selection to the document that keeps it.
pub fn bindDocument(selection: *runtime.Instance, document: *runtime.Instance) void {
    const impl = implementation orelse return;
    const step = impl.bind_document orelse return;
    step(selection, document);
}

/// Selection alone sets/clears Range's weak link back to its selection.
pub fn associateRange(range: *runtime.Instance, selection: *runtime.Instance, associated: bool) void {
    const step = (implementation orelse return).associate_range orelse return;
    step(range, selection, associated);
}

/// A live selected Range changed: keep it associated while it stays in the
/// document, otherwise dissociate; queue the event without ever running script
/// inside the DOM mutation algorithm.
pub fn rangeMutated(selection: *runtime.Instance, range: *runtime.Instance, containers_changed: bool) void {
    const step = (implementation orelse return).range_mutated orelse return;
    step(selection, range, containers_changed);
}

/// Ask the owning control for its flag each time. Textarea state is stored
/// by value in a map, so a task must never keep a pointer into that map.
pub const SelectionchangeFlag = *const fn (*runtime.Instance) ?*bool;

/// Selection API, schedule a selectionchange event, steps 1-3. Called only
/// after the control's selection changes in extent or direction.
///
/// Browser deviation for shadow-tree controls: notify the document instead
/// of dispatching a composed control event. Chrome/Firefox pass
/// selection/textcontrols/selectionchange-on-shadow-dom.html (1/1 each,
/// Safari 0/1; WPT cc74d2669f). Blink's TextControlElement::
/// ScheduleSelectionchangeEventOnThisOrDocument makes the same distinction.
pub fn scheduleTextControlSelectionchange(element: *runtime.Instance, flag: SelectionchangeFlag) !void {
    const document = (try interfaces.Node.get_ownerDocument(element)) orelse return;
    const root = try interfaces.Node.call_getRootNode(element, .notPassed());
    if (root.stateAs(interfaces.ShadowRoot.State) != null) {
        const selection = (try interfaces.Document.call_getSelection(document)) orelse return;
        const step = (implementation orelse return).schedule_change orelse return;
        return step(selection);
    }

    if ((flag(element) orelse return).*) return; // Scheduling step 1.
    const loop = element.ctx.getOptionalEventLoop() orelse return;
    const hold = try engine.retainValue(element.ctx, .{ .instance = element });
    errdefer hold.release();
    const allocator = element.ctx.allocator;
    const task = try allocator.create(TextControlSelectionchangeTask);
    task.* = .{
        .allocator = allocator,
        .element = element,
        .generation = runtime.SlabAllocator.generationOf(element),
        .hold = hold,
        .flag = flag,
    };
    // Step 2 before handing ownership to the queue, which may drop/free the
    // task synchronously. Re-read the flag instead of retaining a map entry.
    const scheduled = flag(element) orelse {
        task.destroy();
        return;
    };
    scheduled.* = true;
    // Step 3: the existing loop is FIFO; task-source discrimination remains
    // an event-loop follow-up (codex-selection Q5), as for document events.
    loop.queueTask(.{
        .callback = &TextControlSelectionchangeTask.run,
        .context = task,
        .drop = &TextControlSelectionchangeTask.drop,
        .document = document,
        .document_generation = runtime.SlabAllocator.generationOf(document),
    });
    // Do not read task after the handoff.
}

const TextControlSelectionchangeTask = struct {
    allocator: std.mem.Allocator,
    element: *runtime.Instance,
    generation: u64,
    hold: engine.Owned,
    flag: SelectionchangeFlag,

    fn clearFlag(self: *TextControlSelectionchangeTask) void {
        if (runtime.SlabAllocator.generationOf(self.element) != self.generation) return;
        if (self.flag(self.element)) |scheduled| scheduled.* = false;
    }

    fn run(context: ?*anyopaque) void {
        const self: *TextControlSelectionchangeTask = @ptrCast(@alignCast(context orelse return));
        defer self.destroy();
        // Firing step 1: clear before dispatch, so a listener may queue again.
        self.clearFlag();
        if (runtime.SlabAllocator.generationOf(self.element) != self.generation) return;
        if (self.element.ctx.engine_ctx == null) return;
        engine.runTaskInRealm(self.element.ctx, steps, self) catch {};
    }

    fn steps(context: ?*anyopaque) void {
        const self: *TextControlSelectionchangeTask = @ptrCast(@alignCast(context orelse return));
        // Firing step 2: trusted, bubbling, not cancelable, not composed.
        const event = interfaces.Event.call_constructor(self.element.ctx, .initInterned("selectionchange"), .passed(.{ .bubbles = true })) catch return;
        const generation = runtime.SlabAllocator.generationOf(event);
        defer event.releaseIfUnwrapped(generation);
        const hold = engine.retainValue(self.element.ctx, .{ .instance = event }) catch return;
        defer hold.release();
        _ = fire_event.dispatchTrusted(self.element, event) catch {};
    }

    fn drop(context: ?*anyopaque) void {
        const self: *TextControlSelectionchangeTask = @ptrCast(@alignCast(context orelse return));
        self.clearFlag();
        self.destroy();
    }

    fn destroy(self: *TextControlSelectionchangeTask) void {
        self.hold.release();
        self.allocator.destroy(self);
    }
};
