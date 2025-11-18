//! Implementation for CanvasPath interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const CanvasPath = @import("interfaces").CanvasPath;

pub const State = CanvasPath.State;

pub const ImplError = error{
    NotImplemented,
};

/// Initialize instance
pub fn init(instance: *runtime.Instance) void {
    _ = instance;
    // TODO: Initialize your instance state here
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    _ = instance;
    // TODO: Clean up your instance resources here
}

/// Operation: closePath
pub fn call_closePath(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: moveTo
pub fn call_moveTo(instance: *runtime.Instance, x: f64, y: f64) ImplError!void {
    _ = instance;
    _ = x;
    _ = y;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: lineTo
pub fn call_lineTo(instance: *runtime.Instance, x: f64, y: f64) ImplError!void {
    _ = instance;
    _ = x;
    _ = y;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: quadraticCurveTo
pub fn call_quadraticCurveTo(instance: *runtime.Instance, cpx: f64, cpy: f64, x: f64, y: f64) ImplError!void {
    _ = instance;
    _ = cpx;
    _ = cpy;
    _ = x;
    _ = y;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: bezierCurveTo
pub fn call_bezierCurveTo(instance: *runtime.Instance, cp1x: f64, cp1y: f64, cp2x: f64, cp2y: f64, x: f64, y: f64) ImplError!void {
    _ = instance;
    _ = cp1x;
    _ = cp1y;
    _ = cp2x;
    _ = cp2y;
    _ = x;
    _ = y;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: arcTo
pub fn call_arcTo(instance: *runtime.Instance, x1: f64, y1: f64, x2: f64, y2: f64, radius: f64) ImplError!void {
    _ = instance;
    _ = x1;
    _ = y1;
    _ = x2;
    _ = y2;
    _ = radius;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: rect
pub fn call_rect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64) ImplError!void {
    _ = instance;
    _ = x;
    _ = y;
    _ = w;
    _ = h;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: roundRect
pub fn call_roundRect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64, radii: anyopaque) ImplError!void {
    _ = instance;
    _ = x;
    _ = y;
    _ = w;
    _ = h;
    _ = radii;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: arc
pub fn call_arc(instance: *runtime.Instance, x: f64, y: f64, radius: f64, startAngle: f64, endAngle: f64, counterclockwise: bool) ImplError!void {
    _ = instance;
    _ = x;
    _ = y;
    _ = radius;
    _ = startAngle;
    _ = endAngle;
    _ = counterclockwise;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: ellipse
pub fn call_ellipse(instance: *runtime.Instance, x: f64, y: f64, radiusX: f64, radiusY: f64, rotation: f64, startAngle: f64, endAngle: f64, counterclockwise: bool) ImplError!void {
    _ = instance;
    _ = x;
    _ = y;
    _ = radiusX;
    _ = radiusY;
    _ = rotation;
    _ = startAngle;
    _ = endAngle;
    _ = counterclockwise;
    // TODO: Implement operation
    return error.NotImplemented;
}

