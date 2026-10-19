const std = @import("std");
const runtime = @import("runtime");
const xhr = @import("xhr");

test "a retired slab generation stops synchronous XHR events and post-fetch state reads" {
    const Recorder = struct {
        slab: *runtime.SlabAllocator,
        owner: *runtime.Instance,
        generation: u64,
        state: *xhr.XMLHttpRequestState,
        retired: bool = false,
        names: [4]xhr.XHREventType = undefined,
        count: usize = 0,

        fn alive(data: *anyopaque) bool {
            const self: *@This() = @ptrCast(@alignCast(data));
            return runtime.SlabAllocator.generationOf(self.owner) == self.generation;
        }

        fn fire(data: *anyopaque, target: xhr.EventTargetKind, kind: xhr.XHREventType, _: ?xhr.ProgressEventData) void {
            const self: *@This() = @ptrCast(@alignCast(data));
            std.debug.assert(target == .xhr);
            self.names[self.count] = kind;
            self.count += 1;
            if (kind == .@"error") {
                self.slab.free(self.owner);
                self.retired = true;
                // The state stays allocated for the test. Any post-fetch
                // read after the owner dies would observe this sentinel and
                // throw TimeoutError instead of returning through the guard.
                self.state.timed_out_flag = true;
            }
        }
    };
    const methods = .{};
    const vtable: runtime.VTable = .{ .name = "pm2-sync-owner", .deinit = null, .methods_ptr = &methods };
    var slab = runtime.SlabAllocator.init(std.testing.allocator);
    defer slab.deinit();
    const owner = try slab.alloc(&vtable);
    var state = xhr.XMLHttpRequestState.init(std.testing.allocator);
    defer state.deinit();
    var recorder: Recorder = .{
        .slab = &slab,
        .owner = owner,
        .generation = runtime.SlabAllocator.generationOf(owner),
        .state = &state,
    };
    defer if (!recorder.retired) slab.free(owner);
    try xhr.open.open(&state, "GET", "pm2-unsupported-scheme://network-error", false, null, null, null, false);
    state.send_flag = true;
    state.event_sink = .{ .ctx = &recorder, .fire = Recorder.fire };

    // Q13: this pins a defensive continuation. No realm ends while script
    // runs; the Browser test separately pins frame removal's live realm.
    try xhr.send.sendSync(&state, null, .{ .context = &recorder, .is_live = Recorder.alive });
    try std.testing.expect(recorder.retired);
    try std.testing.expectEqual(runtime.SlabAllocator.dead_generation, runtime.SlabAllocator.generationOf(owner));
    try std.testing.expectEqualSlices(xhr.XHREventType, &.{ .readystatechange, .@"error" }, recorder.names[0..recorder.count]);
}
