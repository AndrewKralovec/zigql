const std = @import("std");
const ast = @import("ast.zig");
const Parser = @import("../parser.zig").Parser;
const TokenKind = @import("../lib/tokens.zig").TokenKind;

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

    if (directives.?.len == 0) {
        return error.UnexpectedToken;
    }

    return ast.ScalarTypeExtensionNode{
        .name = name,
        .directives = directives,
    };
}
