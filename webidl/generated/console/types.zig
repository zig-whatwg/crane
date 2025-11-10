//! Console supporting types

const std = @import("std");

/// Log level enumeration
pub const LogLevel = enum {
    assert_level,
    clear,
    debug,
    error_level,
    info,
    log,
    trace,
    warn,
    dir,
    dirxml,
    group,
    group_collapsed,
    group_end,
    count,
    count_reset,
    time,
    time_log,
    time_end,
};

/// Group state
pub const Group = struct {
    collapsed: bool,
};
