//! Format specifier parsing

const std = @import("std");

pub const FormatSpec = enum {
    string,
    integer,
    float,
    object,
    css,
    none,
};
