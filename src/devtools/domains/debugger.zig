//! The Debugger domain on page sessions: V8's inspector (design 3.4), through `dispatchRaw`.
//!
//! TODO(lane cdph): the handlers. Until then every Debugger command answers
//! "'Debugger.<command>' wasn't found" (src/devtools/dispatch.zig). The handler
//! interface is src/devtools/README.md's.

const PageSession = @import("../page_session.zig").PageSession;
const protocol = @import("../protocol/root.zig");

/// Per-session state of the domain.
pub const State = struct {};
