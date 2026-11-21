//! The Input domain on page sessions: trusted input through src/html/user_input.zig (design 3.7).
//!
//! TODO(lane cdpt): the handlers. Until then every Input command answers
//! "'Input.<command>' wasn't found" (src/devtools/dispatch.zig). The handler
//! interface is src/devtools/README.md's.

const PageSession = @import("../page_session.zig").PageSession;
const protocol = @import("../protocol/root.zig");

/// Per-session state of the domain.
pub const State = struct {};
