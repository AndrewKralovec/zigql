const std = @import("std");
const ast = @import("../../ast/ast.zig");
const Parser = @import("../parser.zig").Parser;
const TokenKind = @import("../../lexer/tokens.zig").TokenKind;

const parseStringLiteral = @import("./value.zig").parseStringLiteral;

pub fn parseDescription(p: *Parser) !?ast.StringValueNode {
    p.debug("parseDescription");
    if (!try p.peekKind(TokenKind.StringValue)) {
        return null;
    }

    const val = try parseStringLiteral(p);
    return val;
}

//
// Test cases for description
//

test "should parse a type definition with a description" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const source =
        \\ "A user in the system"
        \\ type User {
        \\   name: String
        \\ }
    ;
    var p = Parser.init(allocator, source, .{});
    const doc = try p.parse();
    try std.testing.expect(doc.definitions.len == 1);

    const dn = doc.definitions[0];
    try std.testing.expect(dn == ast.DefinitionNode.TypeSystemDefinition);

    const tsd = dn.TypeSystemDefinition;
    try std.testing.expect(tsd == ast.TypeSystemDefinitionNode.TypeDefinition);

    const td = tsd.TypeDefinition;
    try std.testing.expect(td == ast.TypeDefinitionNode.ObjectTypeDefinition);

    const obj = td.ObjectTypeDefinition;
    try std.testing.expect(std.mem.eql(u8, obj.name.value, "User"));
    try std.testing.expect(obj.description != null);
    try std.testing.expect(std.mem.eql(u8, obj.description.?.value, "\"A user in the system\""));
}
