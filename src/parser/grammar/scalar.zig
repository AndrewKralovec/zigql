const std = @import("std");
const ast = @import("../../ast/ast.zig");
const Parser = @import("../parser.zig").Parser;
const TokenKind = @import("../../lexer/tokens.zig").TokenKind;

const parseDescription = @import("./description.zig").parseDescription;
const parseName = @import("./name.zig").parseName;
const parseConstDirectives = @import("./directive.zig").parseConstDirectives;

pub fn parseScalarTypeDefinition(p: *Parser) !ast.ScalarTypeDefinitionNode {
    p.debug("parseScalarTypeDefinition");
    const description = try parseDescription(p);
    _ = try p.expectKeyword(ast.SyntaxKeyWord.Scalar);
    const name = try parseName(p);
    const directives = try parseConstDirectives(p);
    return ast.ScalarTypeDefinitionNode{
        .description = description,
        .name = name,
        .directives = directives,
    };
}

pub fn parseScalarTypeExtension(p: *Parser) !ast.ScalarTypeExtensionNode {
    p.debug("parseScalarTypeExtension");
    _ = try p.expectKeyword(ast.SyntaxKeyWord.Extend);
    _ = try p.expectKeyword(ast.SyntaxKeyWord.Scalar);
    const name = try parseName(p);
    const directives = try parseConstDirectives(p);

    const directives_empty = if (directives) |d| d.len == 0 else true;
    if (directives_empty) {
        return error.UnexpectedToken;
    }

    return ast.ScalarTypeExtensionNode{
        .name = name,
        .directives = directives,
    };
}

//
// Test cases for scalar
//

test "should parse a scalar type definition" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const source =
        \\ scalar DateTime
    ;
    var p = Parser.init(allocator, source, .{});
    const doc = try p.parse();
    try std.testing.expect(doc.definitions.len == 1);

    const dn = doc.definitions[0];
    try std.testing.expect(dn == ast.DefinitionNode.TypeSystemDefinition);

    const def = dn.TypeSystemDefinition;
    try std.testing.expect(def == ast.TypeSystemDefinitionNode.TypeDefinition);

    const type_def = def.TypeDefinition;
    try std.testing.expect(type_def == ast.TypeDefinitionNode.ScalarTypeDefinition);

    const scalar_def = type_def.ScalarTypeDefinition;
    try std.testing.expect(std.mem.eql(u8, scalar_def.name.value, "DateTime"));
}
