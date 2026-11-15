//! HTML "abort a document and its descendants": queued descendant tasks.
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const document_lifecycle = @import("dom").document_lifecycle;
const browser_state = @import("dom").browser_state;

/// One descendant's abort task. Its wrapper is held until the callback or
/// dropped end returns; another frame's abort listener may collect/remove it.
pub const DescendantAbort = struct {
    parent: *runtime.Instance,
    parent_ctx: runtime.Context,
    parent_generation: u64,
    parent_pin: ?engine.Owned,
    document: *runtime.Instance,
    ctx: runtime.Context,
    generation: u64,
    pin: ?engine.Owned,
    allocator: std.mem.Allocator,
    navigable_id: u64,

    pub fn queue(parent: *runtime.Instance, document: *runtime.Instance, navigable_id: u64) void {
        const ctx = document.ctx;
        const allocator = ctx.allocator;
        const task = allocator.create(@This()) catch return;
        task.* = .{
            .parent = parent,
            .parent_ctx = parent.ctx,
            .parent_generation = runtime.SlabAllocator.generationOf(parent),
            .parent_pin = engine.retainValue(parent.ctx, .{ .instance = parent }) catch null,
            .document = document,
            .ctx = ctx,
            .generation = runtime.SlabAllocator.generationOf(document),
            .pin = engine.retainValue(document.ctx, .{ .instance = document }) catch null,
            .allocator = allocator,
            .navigable_id = navigable_id,
        };
        const loop = ctx.getOptionalEventLoop() orelse return run(task);
        // Queue a global task fixes its associated Document at enqueue.
        // A navigation that replaces that Document makes this task inactive.
        loop.queueTask(.{ .callback = run, .context = task, .drop = drop, .document = document, .document_generation = task.generation });
    }

    fn drop(context: ?*anyopaque) void {
        const task: *@This() = @ptrCast(@alignCast(context.?));
        task.destroy();
    }

    fn run(context: ?*anyopaque) void {
        const task: *@This() = @ptrCast(@alignCast(context.?));
        defer task.destroy();
        if (!task.ctx.hasEngine()) return;
        if (runtime.SlabAllocator.generationOf(task.document) != task.generation) return;
        const document = task.activeDocument() orelse return;
        const ctx = document.ctx;
        if (!ctx.hasEngine()) return;
        const pin = engine.retainValue(ctx, .{ .instance = document }) catch return;
        defer pin.release();
        var target: Target = .{ .task = task, .document = document };
        engine.runTaskInRealm(ctx, steps, &target) catch {};
    }

    const Target = struct { task: *DescendantAbort, document: *runtime.Instance };

    fn steps(context: ?*anyopaque) void {
        const target: *Target = @ptrCast(@alignCast(context.?));
        const task = target.task;
        const document_generation = runtime.SlabAllocator.generationOf(target.document);
        // The descendant's load ends as the stopped document's does
        // (Window.stop, Document's lifecycleStopLoad): readiness "complete",
        // no load event at it or its container, and its container no longer
        // delays the container's document. Stated deviation from HTML, whose
        // aborted descendant still fires load once its cancelled fetches stop
        // delaying it - golden rule 2, mechanism by mechanism as for the
        // stopped document (lifecycleStopLoad's evidence: no load in Chrome
        // and Firefox), here because Blink FrameLoader::StopAllLoaders runs
        // Document::CancelParsing in every local descendant frame, and WebKit
        // FrameLoader::stopAllLoaders stops each local child's loaders.
        // Firefox 159 agrees with Chrome 157: a descendant's navigation in
        // flight is cancelled too, from stop()'s own task or a later one;
        // Safari 27 lets one started in stop()'s own task commit (lane
        // nav2's three-browser probe, 2026-11-14; HTMLIFrameElement's
        // stopLoadingDocument ends those navigations). Only "stop loading"
        // queues these tasks (its step 3).
        //
        // BEFORE the abort: cancelling the descendant's fetches ends what
        // delayed its load, which queues "the end" step 9's task and marks the
        // document ready for post-load tasks - and a stop that came after
        // found its load already on its way (Crane test
        // nav2b11-window-stop-descendants.html: the inner frame's load and its
        // container's fired). Ended first, the queued task completes the
        // load without its events (completeLoading's load_aborted branch), as
        // Blink's CancelParsing marks the load event completed before
        // DocumentLoader::StopLoading cancels the loads.
        if (target.document.ctx.hasEngine()) document_lifecycle.stopLoad(target.document);
        // readystatechange listeners ran: the document may be gone.
        if (runtime.SlabAllocator.generationOf(target.document) == document_generation and target.document.ctx.hasEngine()) {
            document_lifecycle.abort(target.document);
        }
        // Abort callbacks may end either document; the task holds each
        // wrapper and still checks the slab identity before reading state.
        if (!task.parent_ctx.hasEngine() or runtime.SlabAllocator.generationOf(task.parent) != task.parent_generation) return;
        // The spec asks for the navigable's active document again after
        // abort callbacks. A callback may replace it or destroy the frame.
        const active = task.activeDocument() orelse return;
        document_lifecycle.propagateAbort(task.parent, active);
    }

    fn activeDocument(self: *const @This()) ?*runtime.Instance {
        // The parent's Browser's list: its realm stays a readable record
        // after it retires.
        const navigables = browser_state.navigablesOf(self.parent_ctx) orelse return null;
        const navigable = navigables.byId(self.navigable_id) orelse return null;
        if (navigable.orphaned or navigable.is_closed) return null;
        return @ptrCast(@alignCast(navigable.getActiveDocument() orelse return null));
    }

    fn destroy(self: *@This()) void {
        if (self.pin) |held| held.release();
        if (self.parent_pin) |held| held.release();
        self.allocator.destroy(self);
    }
};
