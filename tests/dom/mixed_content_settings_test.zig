//! Mixed Content 4.3's request-client snapshot. requestClient's reporter
//! function pointers need the engine-linked tests/dom target.
const std = @import("std");
const runtime = @import("runtime");
const settings = @import("dom").global_settings;
const methods = struct {}{};
const null_vtable: runtime.VTable = .{ .name = "MixedContentNullTestGlobal", .deinit = null, .methods_ptr = &methods };
const callback_vtable: runtime.VTable = .{ .name = "MixedContentCallbackTestGlobal", .deinit = null, .methods_ptr = &methods };
const Answer = enum { prohibits, allows, fails };

fn ownsNull(global: *runtime.Instance) bool {
    return global.vtable == &null_vtable;
}

fn ownsCallback(global: *runtime.Instance) bool {
    return global.vtable == &callback_vtable;
}

fn originOf(global: *runtime.Instance) anyerror!runtime.USVString {
    return global.ctx.allocator.dupe(u8, "https://example.test");
}

fn falseSetting(_: *runtime.Instance) bool {
    return false;
}

fn restriction(global: *runtime.Instance) error{OutOfMemory}!bool {
    const answer: *const Answer = @ptrCast(@alignCast(global.state));
    switch (answer.*) {
        .prohibits => return true,
        .allows => return false,
        .fails => {
            var failing = std.testing.FailingAllocator.init(global.ctx.allocator, .{ .fail_index = 0 });
            const allocation = try failing.allocator().alloc(u8, 1);
            defer failing.allocator().free(allocation);
            return false;
        },
    }
}

test "mixed content settings: null default, captured answers, and callback OOM cleanup" {
    var context = try runtime.ContextData.init(std.testing.allocator, .{});
    defer context.deinit();
    var answer: Answer = .prohibits;
    var null_global: runtime.Instance = .{ .ctx = &context, .vtable = &null_vtable, .state = &answer };
    var callback_global: runtime.Instance = .{ .ctx = &context, .vtable = &callback_vtable, .state = &answer };

    // Before installation, an unowned global also takes the null default.
    var absent = try settings.requestClient(&null_global);
    defer absent.deinit();
    try std.testing.expect(!absent.request.prohibits_mixed_security_contexts);

    // Window + Worker + these two const-vtable test kinds fill capacity 4.
    settings.install(.{ .owns = &ownsNull, .origin = &originOf, .is_secure_context = &falseSetting, .cross_origin_isolated = &falseSetting });
    settings.install(.{
        .owns = &ownsCallback,
        .origin = &originOf,
        .is_secure_context = &falseSetting,
        .cross_origin_isolated = &falseSetting,
        .prohibits_mixed_security_contexts = &restriction,
    });
    var no_callback = try settings.requestClient(&null_global);
    defer no_callback.deinit();
    try std.testing.expect(!no_callback.request.prohibits_mixed_security_contexts);
    var captured = try settings.requestClient(&callback_global);
    defer captured.deinit();
    try std.testing.expect(captured.request.prohibits_mixed_security_contexts);
    answer = .allows;
    var allowed = try settings.requestClient(&callback_global);
    defer allowed.deinit();
    try std.testing.expect(!allowed.request.prohibits_mixed_security_contexts);
    try std.testing.expect(captured.request.prohibits_mixed_security_contexts);
    answer = .fails;
    // Origin was already allocated; requestClient must free it on error.
    try std.testing.expectError(error.OutOfMemory, settings.requestClient(&callback_global));
}
