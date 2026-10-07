//! Form callbacks capture owning values, including restoration state.
const std = @import("std");
const testing = std.testing;
const Counts = struct { retained: usize = 0, released: usize = 0 };
const Runtime = struct {
    pub const Context = *Counts;
    pub const Instance = struct { id: u32 };
    pub const JSValue = union(enum) { null, instance: *Instance, integer: u32 };
};
const Engine = struct {
    pub const Owned = struct {
        value: Runtime.JSValue,
        counts: ?*Counts = null,
        pub fn release(self: Owned) void {
            if (self.counts) |counts| counts.released += 1;
        }
    };
    pub const CallbackFunction = struct {
        function: Owned,
        context: ?Runtime.Context,
        pub fn release(self: CallbackFunction) void {
            self.function.release();
        }
    };
    pub fn retainValue(context: Runtime.Context, value: Runtime.JSValue) !Owned {
        context.retained += 1;
        return .{ .value = switch (value) {
            .instance => |instance| .{ .integer = instance.id },
            else => value,
        }, .counts = context };
    }
};
const Reaction = @import("html_core").custom_element_reaction.Reaction(Runtime, Engine);

test "CE2 form reactions: associated form survives native retirement and null owns nothing" {
    var counts = Counts{};
    const callback = Engine.CallbackFunction{ .function = .{ .value = .{ .integer = 1 } }, .context = &counts };
    const form = try testing.allocator.create(Runtime.Instance);
    form.* = .{ .id = 41 };
    var reaction = try Reaction.initCallback(testing.allocator, &counts, callback, .form_associated, .{ .form_associated = form });
    testing.allocator.destroy(form);
    try testing.expectEqual(@as(u32, 41), reaction.formValue().integer);
    reaction.deinit();
    var null_reaction = try Reaction.initCallback(testing.allocator, &counts, callback, .form_associated, .{ .form_associated = null });
    try testing.expectEqual(Runtime.JSValue.null, null_reaction.formValue());
    null_reaction.deinit();
    try testing.expectEqual(@as(usize, 3), counts.retained);
    try testing.expectEqual(counts.retained, counts.released);
}

test "CE2 form reactions: each restoration mode retains its state exactly once" {
    var counts = Counts{};
    const callback = Engine.CallbackFunction{ .function = .{ .value = .{ .integer = 1 } }, .context = &counts };
    inline for (.{ .restore, .autocomplete }) |mode| {
        var state = Runtime.Instance{ .id = 9 };
        var reaction = try Reaction.initCallback(testing.allocator, &counts, callback, .form_state_restore, .{
            .form_state_restore = .{ .state = .{ .instance = &state }, .mode = mode },
        });
        state.id = 0;
        try testing.expectEqual(@as(u32, 9), reaction.formValue().integer);
        try testing.expectEqual(mode, reaction.callback_args.?.form_state_restore.mode);
        reaction.deinit();
    }
    try testing.expectEqual(@as(usize, 4), counts.retained);
    try testing.expectEqual(counts.retained, counts.released);
}
