const std = @import("std");
const ast = @import("ast.zig");
const Parser = @import("../parser.zig").Parser;
const TokenKind = @import("../lib/tokens.zig").TokenKind;

const parseDescription = @import("./description.zig").parseDescription;
const parseName = @import("./name.zig").parseName;
const parseConstDirectives = @import("./directive.zig").parseConstDirectives;
const parseFieldsDefinition = @import("./field.zig").parseFieldsDefinition;
const parseNamedType = @import("./type.zig").parseNamedType;

pub fn parseInterfaceTypeDefinition(p: *Parser) !ast.InterfaceTypeDefinitionNode {
    p.debug("parseInterfaceTypeDefinition");
    const description = try parseDescription(p);
    _ = try p.expectKeyword(ast.SyntaxKeyWord.Interface);
    const name = try parseName(p);
    const interfaces = try parseImplementsInterfaces(p);
    const directives = try parseConstDirectives(p);
    const fields = try parseFieldsDefinition(p);

    return ast.InterfaceTypeDefinitionNode{
        .description = description,
        .name = name,
        .interfaces = interfaces,
        .directives = directives,
        .fields = fields,
    };
}

pub fn parseImplementsInterfaces(p: *Parser) !?[]ast.NamedTypeNode {
    p.debug("parseImplementsInterfaces");
    const hasImplements = try p.expectOptionalKeyword(ast.SyntaxKeyWord.Implements);
    if (!hasImplements) {
        return null;
    }

    _ = p.expectOptionalToken(TokenKind.Amp);
    var nodes = std.ArrayList(ast.NamedTypeNode).init(p.allocator);
    defer nodes.deinit();
    while (p.peek()) |_| {
        const name = try parseNamedType(p);
        try nodes.append(name);

        if (!p.expectOptionalToken(TokenKind.Amp)) {
            break;
        }
    }
    return try nodes.toOwnedSlice();
}

pub fn parseInterfaceTypeExtension(p: *Parser) !ast.InterfaceTypeExtensionNode {
    p.debug("parseInterfaceTypeExtension");
    _ = try p.expectKeyword(ast.SyntaxKeyWord.Extend);
    _ = try p.expectKeyword(ast.SyntaxKeyWord.Interface);
    const name = try parseName(p);
    const interfaces = try parseImplementsInterfaces(p);
    const directives = try parseConstDirectives(p);
    const fields = try parseFieldsDefinition(p);

    if (interfaces.?.len == 0 and directives.?.len == 0 and fields.?.len == 0) {
        return error.UnexpectedToken;
    }

    return ast.InterfaceTypeExtensionNode{
        .name = name,
        .interfaces = interfaces,
        .directives = directives,
        .fields = fields,
    };
}
