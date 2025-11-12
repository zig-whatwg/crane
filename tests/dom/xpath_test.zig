//! XPath 1.0 Integration Tests

const std = @import("std");
const dom = @import("dom");

test "xpath - parse simple number" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var parser = try dom.xpath.parser.Parser.init(arena.allocator(), "42");
    const expr = try parser.parse();
    
    try std.testing.expectEqual(dom.xpath.ast.Expr.primary_expr, std.meta.activeTag(expr.*));
}

test "xpath - parse arithmetic" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var parser = try dom.xpath.parser.Parser.init(arena.allocator(), "5 + 3");
    const expr = try parser.parse();
    
    try std.testing.expectEqual(dom.xpath.ast.Expr.additive_expr, std.meta.activeTag(expr.*));
}

test "xpath - evaluate number" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var parser = try dom.xpath.parser.Parser.init(arena.allocator(), "42");
    const expr = try parser.parse();
    
    var node: dom.Node = undefined;
    var ctx = try dom.xpath.context.Context.init(arena.allocator(), &node);
    defer ctx.deinit();
    
    var result = try dom.xpath.evaluator.evaluate(arena.allocator(), expr, &ctx);
    defer result.deinit(arena.allocator());
    
    try std.testing.expectEqual(dom.xpath.value.Value.number, std.meta.activeTag(result));
    try std.testing.expectEqual(@as(f64, 42.0), result.number);
}

test "xpath - evaluate arithmetic" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var parser = try dom.xpath.parser.Parser.init(arena.allocator(), "5 + 3");
    const expr = try parser.parse();
    
    var node: dom.Node = undefined;
    var ctx = try dom.xpath.context.Context.init(arena.allocator(), &node);
    defer ctx.deinit();
    
    var result = try dom.xpath.evaluator.evaluate(arena.allocator(), expr, &ctx);
    defer result.deinit(arena.allocator());
    
    try std.testing.expectEqual(@as(f64, 8.0), result.number);
}

test "xpath - evaluate boolean" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var parser = try dom.xpath.parser.Parser.init(arena.allocator(), "5 > 3");
    const expr = try parser.parse();
    
    var node: dom.Node = undefined;
    var ctx = try dom.xpath.context.Context.init(arena.allocator(), &node);
    defer ctx.deinit();
    
    var result = try dom.xpath.evaluator.evaluate(arena.allocator(), expr, &ctx);
    defer result.deinit(arena.allocator());
    
    try std.testing.expectEqual(true, result.boolean);
}

test "xpath - function call position()" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var parser = try dom.xpath.parser.Parser.init(arena.allocator(), "position()");
    const expr = try parser.parse();
    
    var node: dom.Node = undefined;
    var ctx = try dom.xpath.context.Context.init(arena.allocator(), &node);
    defer ctx.deinit();
    ctx.context_position = 5;
    
    var result = try dom.xpath.evaluator.evaluate(arena.allocator(), expr, &ctx);
    defer result.deinit(arena.allocator());
    
    try std.testing.expectEqual(@as(f64, 5.0), result.number);
}

test "xpath - function call concat()" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var parser = try dom.xpath.parser.Parser.init(arena.allocator(), "concat('Hello', ' ', 'World')");
    const expr = try parser.parse();
    
    var node: dom.Node = undefined;
    var ctx = try dom.xpath.context.Context.init(arena.allocator(), &node);
    defer ctx.deinit();
    
    var result = try dom.xpath.evaluator.evaluate(arena.allocator(), expr, &ctx);
    defer result.deinit(arena.allocator());
    
    try std.testing.expectEqualStrings("Hello World", result.string);
}

test "xpath - complex expression" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var parser = try dom.xpath.parser.Parser.init(arena.allocator(), "(5 + 3) * 2");
    const expr = try parser.parse();
    
    var node: dom.Node = undefined;
    var ctx = try dom.xpath.context.Context.init(arena.allocator(), &node);
    defer ctx.deinit();
    
    var result = try dom.xpath.evaluator.evaluate(arena.allocator(), expr, &ctx);
    defer result.deinit(arena.allocator());
    
    try std.testing.expectEqual(@as(f64, 16.0), result.number);
}
