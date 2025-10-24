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

    if (directives.?.len == 0 and operation_types.?.len == 0) {
        return error.UnexpectedToken;
    }

    return ast.SchemaExtensionNode{
        .directives = directives,
        .operation_types = operation_types,
    };
}
