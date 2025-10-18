const std = @import("std");
const ast = @import("ast.zig");
const Parser = @import("../parser.zig").Parser;
const TokenKind = @import("../lib/tokens.zig").TokenKind;

const parseDescription = @import("./description.zig").parseDescription;
const parseName = @import("./name.zig").parseName;
const parseConstDirectives = @import("./directive.zig").parseConstDirectives;

pub fn parseEnumTypeDefinition(p: *Parser) !ast.EnumTypeDefinitionNode {
    p.debug("parseEnumTypeDefinition");
    const description = try parseDescription(p);
    _ = try p.expectKeyword(ast.SyntaxKeyWord.Enum);
    const name = try parseName(p);
    const directives = try parseConstDirectives(p);
    const values = try parseEnumValuesDefinitions(p);

    return ast.EnumTypeDefinitionNode{
        .description = description,
        .name = name,
        .directives = directives,
        .values = values,
    };
}

pub fn parseEnumValuesDefinitions(p: *Parser) !?[]ast.EnumValueDefinitionNode {
    p.debug("parseEnumValuesDefinitions");
    if (!try p.expectOptionalToken(TokenKind.LCurly)) {
        return null;
    }

    var nodes = std.ArrayList(ast.EnumValueDefinitionNode).init(p.allocator);
    defer nodes.deinit();
    while (p.peek()) |_| {
        const value = try parseEnumValueDefinition(p);
        try nodes.append(value);

        if (try p.expectOptionalToken(TokenKind.RCurly)) {
            break;
        }
    }
    return try nodes.toOwnedSlice();
}

pub fn parseEnumValueDefinition(p: *Parser) !ast.EnumValueDefinitionNode {
    p.debug("parseEnumValueDefinition");
    const description = try parseDescription(p);
    const name = try parseEnumValueName(p);
    const directives = try parseConstDirectives(p);

    return ast.EnumValueDefinitionNode{
        .description = description,
        .name = name,
        .directives = directives,
    };
}

pub fn parseEnumValueName(p: *Parser) !ast.NameNode {
    p.debug("parseEnumValueName");
    const token = p.peek() orelse return error.UnexpectedNullToken;
    if (std.mem.eql(u8, token.data, "true") or
        std.mem.eql(u8, token.data, "false") or
        std.mem.eql(u8, token.data, "null"))
    {
        return error.ReservedEnumValueName;
    }

    const name = try parseName(p);
    return name;
}

pub fn parseEnumTypeExtension(p: *Parser) !ast.EnumTypeExtensionNode {
    p.debug("parseEnumTypeExtension");
    _ = try p.expectKeyword(ast.SyntaxKeyWord.Extend);
    _ = try p.expectKeyword(ast.SyntaxKeyWord.Enum);
    const name = try parseName(p);
    const directives = try parseConstDirectives(p);
    const values = try parseEnumValuesDefinitions(p);

    if (directives.?.len == 0 and values.?.len == 0) {
        return error.UnexpectedToken;
    }

    return ast.EnumTypeExtensionNode{
        .name = name,
        .directives = directives,
        .values = values,
    };
}
