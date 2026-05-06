const std = @import("std");
const ast = @import("../../ast/ast.zig");
const Parser = @import("../parser.zig").Parser;
const TokenKind = @import("../../lexer/tokens.zig").TokenKind;

pub fn parseName(p: *Parser) !ast.NameNode {
    p.debug("parseName");
    const token = try p.expect(TokenKind.Name);
    return ast.NameNode{
        .value = token.data,
    };
}

//
// Test cases for name
//

test "should parse a simple name" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const source =
        \\ {
        \\   hello
        \\ }
    ;
    var p = Parser.init(allocator, source, .{});
    const doc = try p.parse();

    const dn = doc.definitions[0];
    const def = dn.ExecutableDefinition;
    const op = def.OperationDefinition;
    const sel = op.selection_set.?.selections[0];
    const field = sel.Field;

    try std.testing.expect(std.mem.eql(u8, field.name.value, "hello"));
}
