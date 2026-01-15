const std = @import("std");
const ast = @import("ast.zig");
const Parser = @import("../core/parser.zig").Parser;
const TokenKind = @import("../core/tokens.zig").TokenKind;

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
    if (!try p.expectOptionalKeyword(ast.SyntaxKeyWord.Implements)) {
        return null;
    }

    _ = try p.expectOptionalToken(TokenKind.Amp);
    var nodes = std.ArrayList(ast.NamedTypeNode).init(p.allocator);
    defer nodes.deinit();
    while (true) {
        const name = try parseNamedType(p);
        try nodes.append(name);

        if (!try p.expectOptionalToken(TokenKind.Amp)) {
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

    const interfaces_empty = if (interfaces) |i| i.len == 0 else true;
    const directives_empty = if (directives) |d| d.len == 0 else true;
    const fields_empty = if (fields) |f| f.len == 0 else true;
    if (interfaces_empty and directives_empty and fields_empty) {
        return error.UnexpectedToken;
    }

    return ast.InterfaceTypeExtensionNode{
        .name = name,
        .interfaces = interfaces,
        .directives = directives,
        .fields = fields,
    };
}
