//! javascript: URL execution
//!
//! Spec: https://html.spec.whatwg.org/multipage/browsing-the-web.html#evaluate-a-javascript:-url
//!
//! This module handles the execution of javascript: URLs when an anchor element is clicked.
//! The script is executed in the current browsing context and the result is handled
//! according to the spec.

const std = @import("std");
const runtime = @import("runtime");
const v8_engine = @import("v8");
const v8 = v8_engine.ffi;

/// Execute a JavaScript script from a javascript: URL
///
/// Per spec, this:
/// 1. Creates a classic script from the decoded source
/// 2. Runs the script in the target navigable's active document's settings
/// 3. If the result is a string, it would replace the document (not implemented)
/// 4. Otherwise, the navigation doesn't happen but the script still runs
pub fn executeScript(script_source: []const u8) !void {
    std.debug.print("[javascript_url_execution] executeScript: {s}\n", .{script_source});

    // Get the current isolate
    const isolate = v8.v8_Isolate_GetCurrent() orelse {
        std.debug.print("[javascript_url_execution] No current isolate\n", .{});
        return error.NoIsolate;
    };

    // Get the current context
    const v8_ctx = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
        std.debug.print("[javascript_url_execution] No current context\n", .{});
        return error.NoContext;
    };

    // Create a HandleScope for V8 handle allocation
    const handle_scope = v8.v8_HandleScope_New(isolate) orelse {
        std.debug.print("[javascript_url_execution] Failed to create HandleScope\n", .{});
        return error.HandleScopeFailed;
    };
    defer v8.v8_HandleScope_Dispose(handle_scope);

    // Create V8 string from script source
    const source_str = v8.v8_String_NewFromUtf8(isolate, script_source.ptr, @intCast(script_source.len)) orelse {
        std.debug.print("[javascript_url_execution] Failed to create source string\n", .{});
        return error.StringCreateFailed;
    };

    // Compile the script
    const compiled = v8.v8_Script_Compile(v8_ctx, source_str) orelse {
        // Log compile error
        const exception = v8.v8_TryCatch_Exception(v8_ctx);
        if (exception) |exc| {
            const exc_str = v8.v8_Value_ToString(exc, v8_ctx);
            if (exc_str) |str| {
                var buf: [1024]u8 = undefined;
                const len = v8.v8_String_Utf8Length(str);
                const actual_len = @min(@as(usize, @intCast(len)), buf.len - 1);
                _ = v8.v8_String_WriteUtf8(str, &buf, @intCast(actual_len));
                std.debug.print("[javascript_url_execution] Compile error: {s}\n", .{buf[0..actual_len]});
            }
        }
        return error.CompileError;
    };

    std.debug.print("[javascript_url_execution] Script compiled, running...\n", .{});

    // Run the script
    const result = v8.v8_Script_Run(v8_ctx, compiled);

    if (result) |val| {
        // Script executed successfully
        std.debug.print("[javascript_url_execution] Script executed successfully\n", .{});

        // Per spec, if the result is a string, it would replace the document
        // For now, we just run the script and ignore the result
        // (This is what happens for `javascript:void(0)` or `javascript:someFunc()`)
        if (v8.v8_Value_IsString(val)) {
            const str = v8.v8_Value_ToString(val, v8_ctx);
            if (str) |s| {
                var buf: [256]u8 = undefined;
                const len = v8.v8_String_Utf8Length(s);
                const actual_len = @min(@as(usize, @intCast(len)), buf.len - 1);
                _ = v8.v8_String_WriteUtf8(s, &buf, @intCast(actual_len));
                std.debug.print("[javascript_url_execution] Result is string: {s}\n", .{buf[0..actual_len]});
                // TODO: If result is a string, we should navigate to a new document
                // with that string as the body. For now, we ignore this case.
            }
        }
    } else {
        // Check for exception
        const exception = v8.v8_TryCatch_Exception(v8_ctx);
        if (exception) |exc| {
            const exc_str = v8.v8_Value_ToString(exc, v8_ctx);
            if (exc_str) |str| {
                var buf: [1024]u8 = undefined;
                const len = v8.v8_String_Utf8Length(str);
                const actual_len = @min(@as(usize, @intCast(len)), buf.len - 1);
                _ = v8.v8_String_WriteUtf8(str, &buf, @intCast(actual_len));
                std.debug.print("[javascript_url_execution] Runtime error: {s}\n", .{buf[0..actual_len]});
            }
        }
        // Per spec, we just return - the navigation doesn't happen
        std.debug.print("[javascript_url_execution] Script returned null (exception or undefined)\n", .{});
    }
}
