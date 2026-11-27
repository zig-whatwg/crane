//! The `devtools` module of a build without CDP (`-Dcdp=false`): nothing of
//! the remote end is compiled. Its users - the console's
//! --remote-debugging-port, WebDriver's se:cdp - check `enabled` at compile
//! time and answer `unavailable_message`.

/// Whether this build has the Chrome DevTools Protocol remote end.
pub const enabled = false;

/// What a request for CDP answers in this build.
pub const unavailable_message = "this Crane was built without CDP support (-Dcdp=false)";

/// Host C ABI MCP stubs when compiled without CDP (`-Dcdp=false`).
pub const capi = struct {
    pub export fn crane_browser_start_mcp(browser: ?*anyopaque, options: ?*const anyopaque, out: ?*anyopaque) callconv(.c) c_int {
        _ = .{ browser, options, out };
        return 3; // CRANE_ERR_UNSUPPORTED
    }

    pub export fn crane_browser_stop_mcp(browser: ?*anyopaque) callconv(.c) c_int {
        _ = browser;
        return 3; // CRANE_ERR_UNSUPPORTED
    }

    pub export fn crane_mcp_info_free(info: ?*anyopaque) callconv(.c) void {
        _ = info;
    }
};
