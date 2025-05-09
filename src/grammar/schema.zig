const std = @import("std");
const ast = @import("ast.zig");
const Parser = @import("../parser.zig").Parser;
const TokenKind = @import("../lib/tokens.zig").TokenKind;

const parseDescription = @import("./description.zig").parseDescription;
const parseConstDirectives = @import("./directive.zig").parseConstDirectives;
const parseOperationTypeDefinitions = @import("./operation.zig").parseOperationTypeDefinitions;
const parseOptionalOperationTypeDefinitions = @import("./operation.zig").parseOptionalOperationTypeDefinitions;

pub fn parseSchemaDefinition(p: *Parser) !ast.SchemaDefinitionNode {
    p.debug("parseSchemaDefinition");
    const description = try parseDescription(p);
    _ = try p.expectKeyword(ast.SyntaxKeyWord.schema);
    const directives = try parseConstDirectives(p);
    const operationTypes = try parseOperationTypeDefinitions(p);
    return ast.SchemaDefinitionNode{
        .description = description,
        .directives = directives,
        .operationTypes = operationTypes,
    };
}

pub fn parseSchemaExtension(p: *Parser) !ast.SchemaExtensionNode {
    p.debug("parseSchemaExtension");
    try p.expectKeyword(ast.SyntaxKeyWord.extend);
    try p.expectKeyword(ast.SyntaxKeyWord.schema);
    const directives = try parseConstDirectives(p);
    const operationTypes = try parseOptionalOperationTypeDefinitions(p);

    if (directives.?.len == 0 and operationTypes.?.len == 0) {
        return error.UnexpectedToken;
    }

    return ast.SchemaExtensionNode{
        .directives = directives,
        .operationTypes = operationTypes,
    };
}
