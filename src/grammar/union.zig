const std = @import("std");
const ast = @import("ast.zig");
const Parser = @import("../parser.zig").Parser;
const TokenKind = @import("../lib/tokens.zig").TokenKind;

const parseDescription = @import("./description.zig").parseDescription;
const parseName = @import("./name.zig").parseName;
const parseConstDirectives = @import("./directive.zig").parseConstDirectives;
const parseNamedType = @import("./type.zig").parseNamedType;

pub fn parseUnionTypeDefinition(p: *Parser) !ast.UnionTypeDefinitionNode {
    p.debug("parseUnionTypeDefinition");
    const description = try parseDescription(p);
    _ = try p.expectKeyword(ast.SyntaxKeyWord.Union);
    const name = try parseName(p);
    const directives = try parseConstDirectives(p);
    const types = try parseUnionMemberTypes(p);

    return ast.UnionTypeDefinitionNode{
        .description = description,
        .name = name,
        .directives = directives,
        .types = types,
    };
}

pub fn parseUnionMemberTypes(p: *Parser) !?[]ast.NamedTypeNode {
    p.debug("parseUnionMemberTypes");
    if (!try p.expectOptionalToken(TokenKind.Eq)) {
        return null;
    }

    _ = try p.expectOptionalToken(TokenKind.Pipe);
    var nodes = std.ArrayList(ast.NamedTypeNode).init(p.allocator);
    defer nodes.deinit();
    while (p.peek()) |_| {
        const name = try parseNamedType(p);
        try nodes.append(name);

        if (!try p.expectOptionalToken(TokenKind.Pipe)) {
            break;
        }
    }
    return try nodes.toOwnedSlice();
}

pub fn parseUnionTypeExtension(p: *Parser) !ast.UnionTypeExtensionNode {
    p.debug("parseUnionTypeExtension");
    _ = try p.expectKeyword(ast.SyntaxKeyWord.Extend);
    _ = try p.expectKeyword(ast.SyntaxKeyWord.Union);
    const name = try parseName(p);
    const directives = try parseConstDirectives(p);
    const types = try parseUnionMemberTypes(p);

    if (directives.?.len == 0 and types.?.len == 0) {
        return error.UnexpectedToken;
    }

    return ast.UnionTypeExtensionNode{
        .name = name,
        .directives = directives,
        .types = types,
    };
}
