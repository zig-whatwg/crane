//! HTML "abort a document and its descendants": queued descendant tasks.
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const document_lifecycle = @import("dom").document_lifecycle;
const BrowsingContext = @import("html_core").BrowsingContext;

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
        document_lifecycle.abort(target.document);
        // Abort callbacks may end either document; the task holds each
        // wrapper and still checks the slab identity before reading state.
        if (!task.parent_ctx.hasEngine() or runtime.SlabAllocator.generationOf(task.parent) != task.parent_generation) return;
        // The spec asks for the navigable's active document again after
        // abort callbacks. A callback may replace it or destroy the frame.
        const active = task.activeDocument() orelse return;
        document_lifecycle.propagateAbort(task.parent, active);
    }

    fn activeDocument(self: *const @This()) ?*runtime.Instance {
        const navigable = BrowsingContext.byId(self.navigable_id) orelse return null;
        if (navigable.orphaned or navigable.is_closed) return null;
        return @ptrCast(@alignCast(navigable.getActiveDocument() orelse return null));
    }

    fn destroy(self: *@This()) void {
        if (self.pin) |held| held.release();
        if (self.parent_pin) |held| held.release();
        self.allocator.destroy(self);
    }
};
