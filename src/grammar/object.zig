const std = @import("std");
const ast = @import("ast.zig");
const Parser = @import("../core/parser.zig").Parser;
const TokenKind = @import("../core/tokens.zig").TokenKind;

const parseDescription = @import("./description.zig").parseDescription;
const parseName = @import("./name.zig").parseName;
const parseImplementsInterfaces = @import("./interface.zig").parseImplementsInterfaces;
const parseConstDirectives = @import("./directive.zig").parseConstDirectives;
const parseFieldsDefinition = @import("./field.zig").parseFieldsDefinition;

pub fn parseObjectTypeDefinition(p: *Parser) !ast.ObjectTypeDefinitionNode {
    p.debug("parseObjectTypeDefinition");
    const description = try parseDescription(p);
    _ = try p.expectKeyword(ast.SyntaxKeyWord.Type);

    const name = try parseName(p);
    const interfaces = try parseImplementsInterfaces(p);
    const directives = try parseConstDirectives(p);
    const fields = try parseFieldsDefinition(p);
    return ast.ObjectTypeDefinitionNode{
        .description = description,
        .name = name,
        .interfaces = interfaces,
        .directives = directives,
        .fields = fields,
    };
}

pub fn parseObjectTypeExtension(p: *Parser) !ast.ObjectTypeExtensionNode {
    p.debug("parseObjectTypeExtension");
    _ = try p.expectKeyword(ast.SyntaxKeyWord.Extend);
    _ = try p.expectKeyword(ast.SyntaxKeyWord.Type);
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

    return ast.ObjectTypeExtensionNode{
        .name = name,
        .interfaces = interfaces,
        .directives = directives,
        .fields = fields,
    };
}
