const std = @import("std");
const runtime = @import("runtime");
const owners = @import("dom").document_fetches;

test "full fetch owner table rejects overflow and deduplicates an existing owner" {
    if (comptime !@hasDecl(owners, "OwnerSlots") or !@hasDecl(owners, "tryInstall")) {
        try std.testing.expect(false);
        return;
    } else {
        const Callbacks = struct {
            fn first(_: runtime.Context) void {}
            fn second(context: runtime.Context) void {
                std.mem.doNotOptimizeAway(context);
            }
        };
        const owner: owners.Owner = .{ .discard = Callbacks.first };
        var slots: @field(owners, "OwnerSlots") = .{owner} ** 12;
        try @field(owners, "tryInstall")(&slots, owner);
        try std.testing.expectError(error.OwnerSlotsFull, @field(owners, "tryInstall")(&slots, .{ .discard = Callbacks.second }));
    }
}
