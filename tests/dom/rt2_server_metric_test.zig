const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const Metric = std.meta.Child(@FieldType(@import("dom").performance_timeline.ResourceTiming, "server_timing"));

test "Server-Timing objects own their scalar metric data and serialize it" {
    const Run = struct {
        fn run(result: *?anyerror) void {
            check() catch |err| {
                result.* = err;
            };
        }

        fn check() !void {
            const allocator = std.testing.allocator;
            interfaces.process_hooks.startHooksForTest();
            runtime.initializeRuntime(allocator);
            defer runtime.deinitializeRuntime();
            var ctx = try runtime.ContextData.init(allocator, .{});
            defer ctx.deinit();
            var name = [_]u8{ 'd', 'b' };
            var description = [_]u8{ 'h', 'i', 't' };
            const object = try interfaces.PerformanceServerTiming.initWith(allocator, &ctx, .{
                .metric = Metric{ .name = &name, .duration = 12.5, .description = &description },
            });
            defer runtime.Instance.deinit(object);
            name[0] = 'x';
            description[0] = 'x';
            try std.testing.expectEqualStrings("db", (try interfaces.PerformanceServerTiming.get_name(object)).asSlice());
            try std.testing.expectEqual(@as(f64, 12.5), try interfaces.PerformanceServerTiming.get_duration(object));
            try std.testing.expectEqualStrings("hit", (try interfaces.PerformanceServerTiming.get_description(object)).asSlice());
            const json = try interfaces.PerformanceServerTiming.call_toJSON(object);
            try std.testing.expectEqualStrings("db", json.name.asSlice());
            try std.testing.expectEqualStrings("hit", json.description.asSlice());
            try std.testing.expectEqual(@as(f64, 12.5), json.duration);
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    if (result) |err| return err;
}
