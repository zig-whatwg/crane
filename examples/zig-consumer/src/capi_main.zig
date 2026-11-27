const std = @import("std");
const c = @import("crane_c");

pub const std_options: std.Options = .{
    .log_level = .warn,
    .signal_stack_size = null,
};

pub fn main(init: std.process.Init) !void {
    var proc_opts = std.mem.zeroes(c.crane_process_options_t);
    proc_opts.struct_size = @sizeOf(c.crane_process_options_t);
    proc_opts.snapshot_path = "";
    if (c.crane_process_init(&proc_opts) != c.CRANE_OK) return error.ProcessInitFailed;
    defer c.crane_process_shutdown();

    var browser_opts = std.mem.zeroes(c.crane_browser_options_t);
    browser_opts.struct_size = @sizeOf(c.crane_browser_options_t);
    var browser: ?*c.crane_browser_t = null;
    if (c.crane_browser_create(&browser_opts, &browser) != c.CRANE_OK) return error.BrowserCreateFailed;
    defer c.crane_browser_destroy(browser);

    var tab: c.crane_tab_id = 0;
    if (c.crane_tab_create(browser, null, false, &tab) != c.CRANE_OK) return error.TabCreateFailed;

    var nav_result = std.mem.zeroes(c.crane_navigate_result_t);
    if (c.crane_tab_navigate(
        browser,
        tab,
        "data:text/html,<title>C ABI Consumer</title>",
        c.CRANE_READY_COMPLETE,
        &nav_result,
    ) != c.CRANE_OK) {
        return error.NavigateFailed;
    }
    defer c.crane_navigate_result_free(&nav_result);

    const expr = "\"ran \" + (6 * 7)";
    var eval_result = std.mem.zeroes(c.crane_evaluate_result_t);
    if (c.crane_tab_evaluate(browser, tab, expr.ptr, expr.len, 0, &eval_result) != c.CRANE_OK) {
        return error.EvaluateFailed;
    }
    defer c.crane_evaluate_result_free(&eval_result);

    if (eval_result.exception or eval_result.json == null) return error.EvalException;
    const json_slice = std.mem.span(eval_result.json);

    var parsed = try std.json.parseFromSlice(std.json.Value, std.heap.c_allocator, json_slice, .{});
    defer parsed.deinit();
    if (parsed.value != .object) return error.UnexpectedResult;
    const val = parsed.value.object.get("value") orelse return error.UnexpectedResult;
    if (val != .string) return error.UnexpectedResult;

    var stdout_buf: [256]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &stdout_buf);
    try stdout.interface.print("{s}\n", .{val.string});
    try stdout.interface.flush();
}
