//! The handler modules of page sessions, by domain, and their per-session
//! state (src/devtools/README.md).
//!
//! A domain is served on page sessions when it is listed here; Browser and
//! Target are the devtools thread's (browser_target.zig) for every session.
//! Adding a domain: its module in this directory, a line in `Handlers`, a
//! field in `States`.

pub const Handlers = struct {
    pub const Page = @import("page.zig");
    pub const Runtime = @import("runtime.zig");
    pub const DOM = @import("dom.zig");
    pub const DOMDebugger = @import("dom_debugger.zig");
    pub const CSS = @import("css.zig");
    pub const Emulation = @import("emulation.zig");
    pub const Log = @import("log.zig");
    pub const Inspector = @import("inspector.zig");
    pub const Performance = @import("performance.zig");
    pub const Audits = @import("audits.zig");
    pub const Debugger = @import("debugger.zig");
    pub const Profiler = @import("profiler.zig");
    pub const HeapProfiler = @import("heap_profiler.zig");
    pub const Input = @import("input.zig");
    pub const Network = @import("network.zig");
    pub const Fetch = @import("fetch.zig");
    pub const Security = @import("security.zig");
    pub const Accessibility = @import("accessibility.zig");
};

/// One field per domain: `session.states.Page`.
pub const States = struct {
    Page: Handlers.Page.State = .{},
    Runtime: Handlers.Runtime.State = .{},
    DOM: Handlers.DOM.State = .{},
    DOMDebugger: Handlers.DOMDebugger.State = .{},
    CSS: Handlers.CSS.State = .{},
    Emulation: Handlers.Emulation.State = .{},
    Log: Handlers.Log.State = .{},
    Inspector: Handlers.Inspector.State = .{},
    Performance: Handlers.Performance.State = .{},
    Audits: Handlers.Audits.State = .{},
    Debugger: Handlers.Debugger.State = .{},
    Profiler: Handlers.Profiler.State = .{},
    HeapProfiler: Handlers.HeapProfiler.State = .{},
    Input: Handlers.Input.State = .{},
    Network: Handlers.Network.State = .{},
    Fetch: Handlers.Fetch.State = .{},
    Security: Handlers.Security.State = .{},
    Accessibility: Handlers.Accessibility.State = .{},
};
