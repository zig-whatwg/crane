//! Processing instructions in the HTML parser: the tokenizer's five
//! processing instruction states, the parse errors they name, and "insert a
//! processing instruction" in every insertion mode that handles the token.
//!
//! Spec: https://html.spec.whatwg.org/multipage/parsing.html#processing-instruction-open-state
//!       (13.2.5.72 - 13.2.5.76, and the tag open state's U+003F (?) branch)
//! Spec: https://html.spec.whatwg.org/multipage/parsing.html#insert-a-processing-instruction
//!
//! The tree cases print the tree as html5lib's tree-construction tests do
//! (html/syntax/parsing/resources/processing-instructions.dat): one line per
//! node, two spaces per level, `<?target data?>` for a processing
//! instruction and `content` above a template's contents.

const std = @import("std");
const testing = std.testing;

const parser = @import("html").parser;
const Tokenizer = parser.Tokenizer;
const TreeBuilder = parser.TreeBuilder;
const TreeNode = parser.TreeNode;
const ParseError = parser.ParseError;

// =============================================================================
// Tokenizer
// =============================================================================

/// The parse errors a tokenizer reported, by code name, comma separated.
const ErrorLog = struct {
    names: std.ArrayList(u8) = .empty,

    fn record(info: ParseError, context: ?*anyopaque) void {
        const self: *ErrorLog = @ptrCast(@alignCast(context.?));
        if (self.names.items.len > 0) self.names.append(testing.allocator, ',') catch return;
        self.names.appendSlice(testing.allocator, @tagName(info.code)) catch return;
    }
};

fn appendCodepoint(output: *std.ArrayList(u8), cp: u21) !void {
    var encoded: [4]u8 = undefined;
    const length = try std.unicode.utf8Encode(cp, &encoded);
    try output.appendSlice(testing.allocator, encoded[0..length]);
}

/// Every token `input` makes, in order: text as it is, `<!--data-->` for a
/// comment, `PI(target|data)` for a processing instruction, `(EOF)` for an
/// end-of-file token. Then the parse errors, after ` errors=`.
fn tokenize(input: []const u8) ![]u8 {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, input);
    defer tokenizer.deinit();
    var errors: ErrorLog = .{};
    defer errors.names.deinit(allocator);
    tokenizer.setErrorCallback(ErrorLog.record, &errors);

    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    while (try tokenizer.nextToken()) |token| {
        var owned = token;
        defer owned.deinit();
        switch (owned) {
            .text_run => |run| try output.appendSlice(allocator, run.data),
            .character => |cp| try appendCodepoint(&output, cp),
            .comment => |comment| {
                try output.appendSlice(allocator, "<!--");
                try output.appendSlice(allocator, comment.getData());
                try output.appendSlice(allocator, "-->");
            },
            .start_tag, .end_tag => |tag| {
                try output.appendSlice(allocator, if (owned == .end_tag) "</" else "<");
                try output.appendSlice(allocator, tag.getTagName());
                try output.append(allocator, '>');
            },
            .processing_instruction => |pi| {
                try output.appendSlice(allocator, "PI(");
                try output.appendSlice(allocator, pi.getTarget());
                try output.append(allocator, '|');
                try output.appendSlice(allocator, pi.getData());
                try output.append(allocator, ')');
            },
            .doctype => try output.appendSlice(allocator, "(doctype)"),
            .eof => try output.appendSlice(allocator, "(EOF)"),
        }
        if (owned == .eof) break;
    }
    try output.appendSlice(allocator, " errors=");
    try output.appendSlice(allocator, errors.names.items);
    return output.toOwnedSlice(allocator);
}

fn expectTokens(input: []const u8, expected: []const u8) !void {
    const actual = try tokenize(input);
    defer testing.allocator.free(actual);
    testing.expectEqualStrings(expected, actual) catch |err| {
        std.debug.print("input: {s}\n", .{input});
        return err;
    };
}

test "<? opens a processing instruction whose target ends at whitespace, ? or >" {
    // 13.2.5.6 tag open state, U+003F (?): the processing instruction open
    // state; 13.2.5.73: the target runs to whitespace, "?" or ">"; 13.2.5.74
    // skips the whitespace after it; 13.2.5.75 ends the token at ">".
    try expectTokens("<?x>", "PI(x|) errors=");
    try expectTokens("<?something good>", "PI(something|good) errors=");
    try expectTokens("<?something else is good>", "PI(something|else is good) errors=");
    try expectTokens("<?hey there?>", "PI(hey|there) errors=");
    try expectTokens("<?hey   there?>", "PI(hey|there) errors=");
    try expectTokens("<?hey\tthere=1?>", "PI(hey|there=1) errors=");
    try expectTokens("<?hey\nthere=1?>", "PI(hey|there=1) errors=");
    try expectTokens("<?hey\x0cthere=1?>", "PI(hey|there=1) errors=");
    try expectTokens("<?one><?two>", "PI(one|)PI(two|) errors=");
    try expectTokens("a<?pi d>b", "aPI(pi|d)b errors=");
}

test "a processing instruction's target is ASCII alphanumerics, - and _, starting with an alpha or _, case kept" {
    // 13.2.5.72: an ASCII alpha or "_" starts the target; 13.2.5.73 appends
    // ASCII alphanumerics, "-" and "_" as they are - no lowercasing.
    try expectTokens("<?UPPERCASE data>", "PI(UPPERCASE|data) errors=");
    try expectTokens("<?all-KINDS-of-CaSeS>", "PI(all-KINDS-of-CaSeS|) errors=");
    try expectTokens("<?_prefix>", "PI(_prefix|) errors=");
    try expectTokens("<?_>", "PI(_|) errors=");
    try expectTokens("<?_-_ data>", "PI(_-_|data) errors=");
    try expectTokens("<?A---------------->", "PI(A----------------|) errors=");
    try expectTokens("<?z0123456789>", "PI(z0123456789|) errors=");
    try expectTokens("<?xla->", "PI(xla-|) errors=");
    // Only the whole target "xml" or "xml-stylesheet" is disallowed.
    try expectTokens("<?xmlfoo>", "PI(xmlfoo|) errors=");
    try expectTokens("<?xml-stylesheetx a>", "PI(xml-stylesheetx|a) errors=");
}

test "the data ends at the first ?> or >, and a ? before anything else is data" {
    // 13.2.5.75 / 13.2.5.76: "?" waits for ">"; any other character appends
    // the "?" and is reconsumed as data.
    try expectTokens("<?hey?there>", "PI(hey|?there) errors=");
    try expectTokens("<?something ? >", "PI(something|? ) errors=");
    try expectTokens("<?something x >", "PI(something|x ) errors=");
    try expectTokens("<?a b??>", "PI(a|b?) errors=");
    try expectTokens("<?a b???c?>", "PI(a|b???c) errors=");
    try expectTokens("<?COMMENT?>", "PI(COMMENT|) errors=");
    try expectTokens("<?COM--MENT?>", "PI(COM--MENT|) errors=");
    try expectTokens("<?t d > ?>", "PI(t|d ) ?> errors=");
    // The data is not markup: no character references, and the first ">" ends it.
    try expectTokens("<?a &amp; x?>", "PI(a|&amp; x) errors=");
    try expectTokens("<?a <b>c", "PI(a|<b)c errors=");
}

test "a target that is xml or xml-stylesheet in any case is a bogus comment from the ?" {
    // 13.2.5.73: disallowed-processing-instruction-target; "convert the
    // temporary buffer to a comment" and reconsume in the bogus comment state.
    try expectTokens("<?xml>", "<!--?xml--> errors=disallowed_processing_instruction_target");
    try expectTokens("<?xml version=\"1.0\"?>", "<!--?xml version=\"1.0\"?--> errors=disallowed_processing_instruction_target");
    try expectTokens("<?XML-stylesheet>", "<!--?XML-stylesheet--> errors=disallowed_processing_instruction_target");
    try expectTokens("<?xML>", "<!--?xML--> errors=disallowed_processing_instruction_target");
    try expectTokens("<?xml-STYLesheet href=a?>", "<!--?xml-STYLesheet href=a?--> errors=disallowed_processing_instruction_target");
}

test "a target that does not start with an ASCII alpha or _ is a bogus comment from the ?" {
    // 13.2.5.72: invalid-first-character-of-processing-instruction-target.
    const code = "invalid_first_character_of_processing_instruction_target";
    try expectTokens("<?1st-place>", "<!--?1st-place--> errors=" ++ code);
    try expectTokens("<?-prefix>", "<!--?-prefix--> errors=" ++ code);
    try expectTokens("<? x>", "<!--? x--> errors=" ++ code);
    try expectTokens("<?>", "<!--?--> errors=" ++ code);
    try expectTokens("<?\u{0665}-star>", "<!--?\u{0665}-star--> errors=" ++ code);
    try expectTokens("<? ", "<!--? -->(EOF) errors=" ++ code);
}

test "a target character outside ASCII alphanumerics, - and _ is a bogus comment from the ?" {
    // 13.2.5.73: invalid-processing-instruction-target.
    const code = "invalid_processing_instruction_target";
    try expectTokens("<?a$>", "<!--?a$--> errors=" ++ code);
    try expectTokens("<?price$value>", "<!--?price$value--> errors=" ++ code);
    try expectTokens("<?namespace:tag>", "<!--?namespace:tag--> errors=" ++ code);
    try expectTokens("<?data.v1>", "<!--?data.v1--> errors=" ++ code);
    try expectTokens("<?a<b>", "<!--?a<b--> errors=" ++ code);
    try expectTokens("<?error-\u{26a0}\u{fe0f}>", "<!--?error-\u{26a0}\u{fe0f}--> errors=" ++ code);
    try expectTokens("<?a$><?b$><?good?>", "<!--?a$--><!--?b$-->PI(good|) errors=" ++ code ++ "," ++ code);
    // The bogus comment state still replaces NULL.
    try expectTokens("<?a\x00b>", "<!--?a\u{fffd}b--> errors=" ++ code ++ ",unexpected_null_character");
}

test "end of file inside a processing instruction drops it and emits only the end of file" {
    // eof-in-processing-instruction: "Such processing instructions are ignored."
    const code = "eof_in_processing_instruction";
    try expectTokens("<?", "(EOF) errors=" ++ code);
    try expectTokens("<?start", "(EOF) errors=" ++ code);
    try expectTokens("<?start?", "(EOF) errors=" ++ code);
    try expectTokens("<?start ", "(EOF) errors=" ++ code);
    try expectTokens("<?start data", "(EOF) errors=" ++ code);
    try expectTokens("<?start ? ?", "(EOF) errors=" ++ code);
    try expectTokens("a<?x d", "a(EOF) errors=" ++ code);
}

// =============================================================================
// Tree construction
// =============================================================================

fn indent(output: *std.ArrayList(u8), depth: usize) !void {
    for (0..depth) |_| try output.appendSlice(testing.allocator, "  ");
}

fn dumpNode(output: *std.ArrayList(u8), node: *TreeNode, depth: usize) !void {
    const allocator = testing.allocator;
    try indent(output, depth);
    var children_depth = depth + 1;
    switch (node.node_type) {
        .element => {
            try output.append(allocator, '<');
            switch (node.namespace) {
                .html => {},
                .svg => try output.appendSlice(allocator, "svg "),
                .mathml => try output.appendSlice(allocator, "math "),
            }
            try output.appendSlice(allocator, node.local_name orelse "");
            try output.appendSlice(allocator, ">\n");
            if (node.namespace == .html and node.hasTagName("template")) {
                try indent(output, depth + 1);
                try output.appendSlice(allocator, "content\n");
                children_depth = depth + 2;
            }
        },
        .text => {
            try output.append(allocator, '"');
            try output.appendSlice(allocator, node.text_content.toSlice());
            try output.appendSlice(allocator, "\"\n");
        },
        .comment => {
            try output.appendSlice(allocator, "<!-- ");
            try output.appendSlice(allocator, node.text_content.toSlice());
            try output.appendSlice(allocator, " -->\n");
        },
        .doctype => {
            try output.appendSlice(allocator, "<!DOCTYPE ");
            try output.appendSlice(allocator, node.doctype_name orelse "");
            try output.appendSlice(allocator, ">\n");
        },
        .processing_instruction => {
            // html5lib's dump: "<?" target " " data "?>".
            try output.appendSlice(allocator, "<?");
            try output.appendSlice(allocator, node.pi_target orelse "");
            try output.append(allocator, ' ');
            try output.appendSlice(allocator, node.text_content.toSlice());
            try output.appendSlice(allocator, "?>\n");
        },
        .document => try output.appendSlice(allocator, "#document\n"),
    }
    var child = node.first_child;
    while (child) |c| : (child = c.next_sibling) try dumpNode(output, c, children_depth);
}

fn dumpChildren(parent: *TreeNode) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(testing.allocator);
    var child = parent.first_child;
    while (child) |c| : (child = c.next_sibling) try dumpNode(&output, c, 0);
    return output.toOwnedSlice(testing.allocator);
}

/// Parse `input` as a document (scripting disabled, as html5lib's
/// `#script-off`) and compare the whole tree.
fn expectDocument(input: []const u8, expected: []const u8) !void {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, input);
    defer tokenizer.deinit();
    var builder = try TreeBuilder.init(allocator, &tokenizer);
    defer builder.deinit();
    try builder.parse();
    const actual = try dumpChildren(builder.document);
    defer allocator.free(actual);
    testing.expectEqualStrings(expected, actual) catch |err| {
        std.debug.print("input: {s}\n", .{input});
        return err;
    };
}

test "in body, a processing instruction token inserts a ProcessingInstruction node" {
    try expectDocument("<body><?something>",
        \\<html>
        \\  <head>
        \\  <body>
        \\    <?something ?>
        \\
    );
    try expectDocument("<body><?something><span>",
        \\<html>
        \\  <head>
        \\  <body>
        \\    <?something ?>
        \\    <span>
        \\
    );
    try expectDocument("<body><?hey there?>",
        \\<html>
        \\  <head>
        \\  <body>
        \\    <?hey there?>
        \\
    );
    try expectDocument("<body><?t d > ?>",
        \\<html>
        \\  <head>
        \\  <body>
        \\    <?t d ?>
        \\    " ?>"
        \\
    );
    try expectDocument("<div><?something good></div>",
        \\<html>
        \\  <head>
        \\  <body>
        \\    <div>
        \\      <?something good?>
        \\
    );
}

test "a bogus-comment target and end of file still make a comment or nothing" {
    try expectDocument("<body><?a$><?b$><?good?>",
        \\<html>
        \\  <head>
        \\  <body>
        \\    <!-- ?a$ -->
        \\    <!-- ?b$ -->
        \\    <?good ?>
        \\
    );
    try expectDocument("<body><?xml-stylesheet>",
        \\<html>
        \\  <head>
        \\  <body>
        \\    <!-- ?xml-stylesheet -->
        \\
    );
    try expectDocument("<body><?start data",
        \\<html>
        \\  <head>
        \\  <body>
        \\
    );
    try expectDocument("<?",
        \\<html>
        \\  <head>
        \\  <body>
        \\
    );
    try expectDocument("<body><? ",
        \\<html>
        \\  <head>
        \\  <body>
        \\    <!-- ?  -->
        \\
    );
}

test "the initial, before html, after after body and after after frameset modes insert it in the Document" {
    try expectDocument("<?something>",
        \\<?something ?>
        \\<html>
        \\  <head>
        \\  <body>
        \\
    );
    try expectDocument("<!DOCTYPE html><?pi a><html>",
        \\<!DOCTYPE html>
        \\<?pi a?>
        \\<html>
        \\  <head>
        \\  <body>
        \\
    );
    try expectDocument("<html><body></body></html><?something>",
        \\<html>
        \\  <head>
        \\  <body>
        \\<?something ?>
        \\
    );
    try expectDocument("<frameset></frameset></html><?pi>",
        \\<html>
        \\  <head>
        \\  <frameset>
        \\<?pi ?>
        \\
    );
}

test "a processing instruction before the doctype leaves the initial mode, so the document is in no-quirks mode" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, "<?pi><!DOCTYPE html><p>");
    defer tokenizer.deinit();
    var builder = try TreeBuilder.init(allocator, &tokenizer);
    defer builder.deinit();
    try builder.parse();
    try testing.expectEqual(parser.QuirksMode.no_quirks, builder.quirks_mode);
}

test "the head modes insert it in the current node" {
    // before head
    try expectDocument("<html><?something><head>",
        \\<html>
        \\  <?something ?>
        \\  <head>
        \\  <body>
        \\
    );
    // in head
    try expectDocument("<head><?something>",
        \\<html>
        \\  <head>
        \\    <?something ?>
        \\  <body>
        \\
    );
    // in head noscript (scripting disabled): the in head rules
    try expectDocument("<noscript><?pi>",
        \\<html>
        \\  <head>
        \\    <noscript>
        \\      <?pi ?>
        \\  <body>
        \\
    );
    // after head
    try expectDocument("<html><head></head><?something><body>",
        \\<html>
        \\  <head>
        \\  <?something ?>
        \\  <body>
        \\
    );
}

test "the text modes keep <? as text" {
    try expectDocument("<script><?something></script>",
        \\<html>
        \\  <head>
        \\    <script>
        \\      "<?something>"
        \\  <body>
        \\
    );
    try expectDocument("<style><?something></style>",
        \\<html>
        \\  <head>
        \\    <style>
        \\      "<?something>"
        \\  <body>
        \\
    );
    try expectDocument("<body><textarea><?something></textarea>",
        \\<html>
        \\  <head>
        \\  <body>
        \\    <textarea>
        \\      "<?something>"
        \\
    );
    try expectDocument("<body><title><?something></title>",
        \\<html>
        \\  <head>
        \\  <body>
        \\    <title>
        \\      "<?something>"
        \\
    );
}

test "the table modes insert it in the current node and never foster-parent it" {
    try expectDocument("<table><?something></table>",
        \\<html>
        \\  <head>
        \\  <body>
        \\    <table>
        \\      <?something ?>
        \\
    );
    try expectDocument("<table><tr><?something></tr></table>",
        \\<html>
        \\  <head>
        \\  <body>
        \\    <table>
        \\      <tbody>
        \\        <tr>
        \\          <?something ?>
        \\
    );
    // in table text: the pending characters are foster-parented, the
    // processing instruction is then reprocessed in "in table".
    try expectDocument("<table>x<?pi></table>",
        \\<html>
        \\  <head>
        \\  <body>
        \\    "x"
        \\    <table>
        \\      <?pi ?>
        \\
    );
    // in caption, in column group, in table body, in cell
    try expectDocument("<table><caption><?pi></caption></table>",
        \\<html>
        \\  <head>
        \\  <body>
        \\    <table>
        \\      <caption>
        \\        <?pi ?>
        \\
    );
    try expectDocument("<table><colgroup><?pi></colgroup></table>",
        \\<html>
        \\  <head>
        \\  <body>
        \\    <table>
        \\      <colgroup>
        \\        <?pi ?>
        \\
    );
    try expectDocument("<table><tbody><?pi></tbody></table>",
        \\<html>
        \\  <head>
        \\  <body>
        \\    <table>
        \\      <tbody>
        \\        <?pi ?>
        \\
    );
    try expectDocument("<table><td><?pi></td></table>",
        \\<html>
        \\  <head>
        \\  <body>
        \\    <table>
        \\      <tbody>
        \\        <tr>
        \\          <td>
        \\            <?pi ?>
        \\
    );
}

test "in template, a processing instruction goes into the template contents" {
    try expectDocument("<template><?pi></template>",
        \\<html>
        \\  <head>
        \\    <template>
        \\      content
        \\        <?pi ?>
        \\  <body>
        \\
    );
    try expectDocument("<body><template><?something></template>",
        \\<html>
        \\  <head>
        \\  <body>
        \\    <template>
        \\      content
        \\        <?something ?>
        \\
    );
}

test "after body and the frameset modes insert it in the html element or the current node" {
    // after body: the html element
    try expectDocument("<html><body></body><?something>",
        \\<html>
        \\  <head>
        \\  <body>
        \\  <?something ?>
        \\
    );
    // in frameset
    try expectDocument("<frameset><?pi></frameset>",
        \\<html>
        \\  <head>
        \\  <frameset>
        \\    <?pi ?>
        \\
    );
    // after frameset
    try expectDocument("<frameset></frameset><?pi>",
        \\<html>
        \\  <head>
        \\  <frameset>
        \\  <?pi ?>
        \\
    );
}

test "in foreign content, a processing instruction is inserted in the current node" {
    try expectDocument("<body><svg><?pi d></svg>",
        \\<html>
        \\  <head>
        \\  <body>
        \\    <svg svg>
        \\      <?pi d?>
        \\
    );
    try expectDocument("<body><math><mi><?pi></mi></math>",
        \\<html>
        \\  <head>
        \\  <body>
        \\    <math math>
        \\      <math mi>
        \\        <?pi ?>
        \\
    );
}

// =============================================================================
// Fragment parsing
// =============================================================================

fn expectFragment(context_name: []const u8, namespace: parser.Namespace, input: []const u8, expected: []const u8) !void {
    const allocator = testing.allocator;
    const context = try TreeNode.initElement(allocator, context_name, namespace);
    defer context.deinit();
    var result = try parser.parseFragment(allocator, context, input, .{});
    defer result.deinit();
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(allocator);
    for (result.children) |child| try dumpNode(&output, child, 0);
    testing.expectEqualStrings(expected, output.items) catch |err| {
        std.debug.print("context: {s}, input: {s}\n", .{ context_name, input });
        return err;
    };
}

test "fragment parsing inserts processing instructions in every context that parses markup" {
    try expectFragment("div", .html, "<?pi data>x",
        \\<?pi data?>
        \\"x"
        \\
    );
    try expectFragment("table", .html, "<?pi><tr></tr>",
        \\<?pi ?>
        \\<tbody>
        \\  <tr>
        \\
    );
    try expectFragment("template", .html, "<?pi a?b>",
        \\<?pi a?b?>
        \\
    );
    try expectFragment("svg", .svg, "<?pi><g/>",
        \\<?pi ?>
        \\<svg g>
        \\
    );
    // A context whose tokenizer starts in RCDATA or RAWTEXT keeps <? as text.
    try expectFragment("textarea", .html, "<?pi>",
        \\"<?pi>"
        \\
    );
    try expectFragment("style", .html, "<?pi>",
        \\"<?pi>"
        \\
    );
}
