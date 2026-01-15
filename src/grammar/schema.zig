const std = @import("std");
const ast = @import("ast.zig");
const Parser = @import("../core/parser.zig").Parser;
const TokenKind = @import("../core/tokens.zig").TokenKind;

const parseDescription = @import("./description.zig").parseDescription;
const parseConstDirectives = @import("./directive.zig").parseConstDirectives;
const parseOperationTypeDefinitions = @import("./operation.zig").parseOperationTypeDefinitions;
const parseOptionalOperationTypeDefinitions = @import("./operation.zig").parseOptionalOperationTypeDefinitions;

pub fn parseSchemaDefinition(p: *Parser) !ast.SchemaDefinitionNode {
    p.debug("parseSchemaDefinition");
    const description = try parseDescription(p);
    _ = try p.expectKeyword(ast.SyntaxKeyWord.Schema);
    const directives = try parseConstDirectives(p);
    const operation_types = try parseOperationTypeDefinitions(p);
    return ast.SchemaDefinitionNode{
        .description = description,
        .directives = directives,
        .operation_types = operation_types,
    };
}

pub fn parseSchemaExtension(p: *Parser) !ast.SchemaExtensionNode {
    p.debug("parseSchemaExtension");
    try p.expectKeyword(ast.SyntaxKeyWord.Extend);
    try p.expectKeyword(ast.SyntaxKeyWord.Schema);
    const directives = try parseConstDirectives(p);
    const operation_types = try parseOptionalOperationTypeDefinitions(p);

    const directives_empty = if (directives) |d| d.len == 0 else true;
    const operation_types_empty = if (operation_types) |o| o.len == 0 else true;
    if (directives_empty and operation_types_empty) {
        return error.UnexpectedToken;
    }

    return ast.SchemaExtensionNode{
        .directives = directives,
        .operation_types = operation_types,
    };
}
