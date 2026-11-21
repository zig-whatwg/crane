//! The Performance domain on page sessions: Performance.enable (design 3.11).
//!
//! TODO(lane cdph): the handlers. Until then every Performance command answers
//! "'Performance.<command>' wasn't found" (src/devtools/dispatch.zig). The handler
//! interface is src/devtools/README.md's.

const PageSession = @import("../page_session.zig").PageSession;
const protocol = @import("../protocol/root.zig");

/// Per-session state of the domain.
pub const State = struct {};
