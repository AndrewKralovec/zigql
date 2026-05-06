const std = @import("std");
const ast = @import("../../ast/ast.zig");
const Parser = @import("../parser.zig").Parser;
const TokenKind = @import("../../lexer/tokens.zig").TokenKind;

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

//
// Test cases for schema
//

test "should parse a schema definition" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const source =
        \\ schema {
        \\   query: Query
        \\   mutation: Mutation
        \\ }
    ;
    var p = Parser.init(allocator, source, .{});
    const doc = try p.parse();

    try std.testing.expect(doc.definitions.len == 1);

    const dn = doc.definitions[0];
    try std.testing.expect(dn == ast.DefinitionNode.TypeSystemDefinition);

    const def = dn.TypeSystemDefinition;
    try std.testing.expect(def == ast.TypeSystemDefinitionNode.SchemaDefinition);

    const schema_def = def.SchemaDefinition;
    try std.testing.expect(schema_def.description == null);
    try std.testing.expect(schema_def.directives == null);
    try std.testing.expect(schema_def.operation_types.len == 2);

    const operation_types = schema_def.operation_types;
    try std.testing.expect(operation_types[0].operation == ast.OperationType.Query);
    try std.testing.expect(std.mem.eql(u8, operation_types[0].type.name.value, "Query"));
    try std.testing.expect(operation_types[1].operation == ast.OperationType.Mutation);
    try std.testing.expect(std.mem.eql(u8, operation_types[1].type.name.value, "Mutation"));
}

test "should parse a schema definition with directives" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const source =
        \\ schema @directive {
        \\   query: Query
        \\   mutation: Mutation
        \\ }
    ;
    var p = Parser.init(allocator, source, .{});
    const doc = try p.parse();
    try std.testing.expect(doc.definitions.len == 1);

    const dn = doc.definitions[0];
    try std.testing.expect(dn == ast.DefinitionNode.TypeSystemDefinition);

    const def = dn.TypeSystemDefinition;
    try std.testing.expect(def == ast.TypeSystemDefinitionNode.SchemaDefinition);

    const schema_def = def.SchemaDefinition;

    try std.testing.expect(schema_def.description == null);
    try std.testing.expect(schema_def.directives != null);
    try std.testing.expect(schema_def.directives.?.len == 1);
}

test "should parse a schema extension" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const source =
        \\ extend schema @directive {
        \\   query: Query
        \\   mutation: Mutation
        \\ }
    ;
    var p = Parser.init(allocator, source, .{});
    const doc = try p.parse();
    try std.testing.expect(doc.definitions.len == 1);

    const dn = doc.definitions[0];
    try std.testing.expect(dn == ast.DefinitionNode.TypeSystemExtension);

    const def = dn.TypeSystemExtension;
    try std.testing.expect(def == ast.TypeSystemExtensionNode.SchemaExtension);
    const schema_ext = def.SchemaExtension;

    try std.testing.expect(schema_ext.directives != null);
    try std.testing.expect(schema_ext.directives.?.len == 1);
    try std.testing.expect(std.mem.eql(u8, schema_ext.directives.?[0].name.value, "directive"));

    try std.testing.expect(schema_ext.operation_types != null);
    try std.testing.expect(schema_ext.operation_types.?.len == 2);
    try std.testing.expect(std.mem.eql(u8, schema_ext.operation_types.?[0].type.name.value, "Query"));
    try std.testing.expect(std.mem.eql(u8, schema_ext.operation_types.?[1].type.name.value, "Mutation"));
    try std.testing.expect(schema_ext.operation_types.?[0].operation == ast.OperationType.Query);
    try std.testing.expect(schema_ext.operation_types.?[1].operation == ast.OperationType.Mutation);
}
