//! A worker script's MIME type check is MIME Sniffing's "JavaScript MIME
//! type" (§4.6, an essence match against its one list): lane core1's B15.
//! script_fetch kept a list of its own, which lacked text/javascript1.0-1.5,
//! text/livescript, text/x-ecmascript, text/x-javascript and
//! application/x-ecmascript - so an HTTP(S) or module worker script served
//! with one of them failed where the browsers run it.

const std = @import("std");
const testing = std.testing;
const workers = @import("html_core").workers;
const script_fetch = workers.script_fetch;

test "every JavaScript MIME type essence passes a worker script's check, classic and module" {
    for ([_][]const u8{
        "application/ecmascript",   "application/javascript", "application/x-ecmascript",
        "application/x-javascript", "text/ecmascript",        "text/javascript",
        "text/javascript1.0",       "text/javascript1.1",     "text/javascript1.2",
        "text/javascript1.3",       "text/javascript1.4",     "text/javascript1.5",
        "text/jscript",             "text/livescript",        "text/x-ecmascript",
        "text/x-javascript",
    }) |essence| {
        for ([_]workers.WorkerType{ .classic, .module }) |worker_type| {
            testing.expect(script_fetch.isValidWorkerScriptType(essence, worker_type)) catch |err| {
                std.debug.print("{s} ({t}) was refused\n", .{ essence, worker_type });
                return err;
            };
        }
    }
    // An essence match is ASCII case-insensitive, and parameters are not part
    // of the essence.
    try testing.expect(script_fetch.isValidWorkerScriptType("Text/JavaScript; charset=utf-8", .module));
}

test "a type that is not a JavaScript MIME type fails a worker script's check" {
    for ([_][]const u8{ "text/plain", "application/json", "text/javascript2.0", "javascript", "", "text/html" }) |content_type| {
        try testing.expect(!script_fetch.isValidWorkerScriptType(content_type, .module));
        try testing.expect(!script_fetch.isValidWorkerScriptType(content_type, .classic));
    }
}
