const std = @import("std");
const ast = @import("../../ast/ast.zig");
const Parser = @import("../parser.zig").Parser;
const TokenKind = @import("../../lexer/tokens.zig").TokenKind;

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

//
// Test cases for object
//

test "should parse a query operation with descriptions" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const source =
        \\ """
        \\ The query description
        \\ """
        \\ type Query {
        \\   users(id: Int): User
        \\ }
    ;
    var p = Parser.init(allocator, source, .{});
    const doc = try p.parse();

    try std.testing.expect(doc.definitions.len == 1);

    const dn = doc.definitions[0];
    try std.testing.expect(dn == ast.DefinitionNode.TypeSystemDefinition);

    const def = dn.TypeSystemDefinition;
    try std.testing.expect(def == ast.TypeSystemDefinitionNode.TypeDefinition);

    const type_def = def.TypeDefinition;
    try std.testing.expect(type_def == ast.TypeDefinitionNode.ObjectTypeDefinition);

    const obj_def = type_def.ObjectTypeDefinition;
    try std.testing.expect(obj_def.description != null);
    try std.testing.expect(std.mem.eql(u8, obj_def.description.?.value, "\"\"\"\n The query description\n \"\"\""));
    try std.testing.expect(std.mem.eql(u8, obj_def.name.value, "Query"));
    try std.testing.expect(obj_def.interfaces == null);
    try std.testing.expect(obj_def.directives == null);
    try std.testing.expect(obj_def.fields != null);
    try std.testing.expect(obj_def.fields.?.len == 1);

    const fields = obj_def.fields.?;

    const field = fields[0];
    const named_type = field.type.NamedType;

    try std.testing.expect(std.mem.eql(u8, field.name.value, "users"));
    try std.testing.expect(std.mem.eql(u8, named_type.name.value, "User"));
    try std.testing.expect(field.arguments != null);
    try std.testing.expect(field.description == null);
    try std.testing.expect(field.directives == null);
    try std.testing.expect(field.type.NamedType.kind == ast.SyntaxKind.NamedType);
}

test "should parse a type definition" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const source =
        \\ type User {
        \\   id: ID
        \\   name: String
        \\   friends: [User]
        \\ }
    ;
    var p = Parser.init(allocator, source, .{});
    const doc = try p.parse();
    try std.testing.expect(doc.definitions.len == 1);

    const dn = doc.definitions[0];
    try std.testing.expect(dn == ast.DefinitionNode.TypeSystemDefinition);

    const def = dn.TypeSystemDefinition;
    try std.testing.expect(def == ast.TypeSystemDefinitionNode.TypeDefinition);

    const type_def = def.TypeDefinition;
    try std.testing.expect(type_def == ast.TypeDefinitionNode.ObjectTypeDefinition);

    const obj_def = type_def.ObjectTypeDefinition;
    try std.testing.expect(obj_def.description == null);
    try std.testing.expect(std.mem.eql(u8, obj_def.name.value, "User"));
    try std.testing.expect(obj_def.interfaces == null);
    try std.testing.expect(obj_def.directives == null);

    try std.testing.expect(obj_def.fields != null);
    try std.testing.expect(obj_def.fields.?.len == 3);
    try std.testing.expect(std.mem.eql(u8, obj_def.fields.?[0].name.value, "id"));
    try std.testing.expect(std.mem.eql(u8, obj_def.fields.?[1].name.value, "name"));
    try std.testing.expect(std.mem.eql(u8, obj_def.fields.?[2].name.value, "friends"));
}

test "should parse nested types like [String!]" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const source =
        \\type Post {
        \\  tags: [String!]!
        \\}
    ;
    var p = Parser.init(allocator, source, .{});
    const doc = try p.parse();

    const def = doc.definitions[0].TypeSystemDefinition.TypeDefinition.ObjectTypeDefinition;
    const tag_field = def.fields.?[0];

    try std.testing.expect(tag_field.type.* == ast.TypeNode.NonNullType); // !
    try std.testing.expect(tag_field.type.*.NonNullType.type.* == ast.TypeNode.ListType); // []
    try std.testing.expect(tag_field.type.*.NonNullType.type.*.ListType.type.* == ast.TypeNode.NonNullType); // !
    try std.testing.expect(tag_field.type.*.NonNullType.type.*.ListType.type.*.NonNullType.type.* == ast.TypeNode.NamedType); // String
    try std.testing.expect(std.mem.eql(u8, tag_field.type.*.NonNullType.type.*.ListType.type.*.NonNullType.type.*.NamedType.name.value, "String"));
}

test "should parse directives on type definition" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const source =
        \\ type User @auth @cached(ttl: 300) {
        \\   id: ID
        \\   name: String
        \\ }
    ;
    var p = Parser.init(allocator, source, .{});
    const doc = try p.parse();

    const obj_def = doc.definitions[0].TypeSystemDefinition.TypeDefinition.ObjectTypeDefinition;

    try std.testing.expect(obj_def.directives != null);
    try std.testing.expect(obj_def.directives.?.len == 2);

    const dir_one = obj_def.directives.?[0];
    try std.testing.expect(std.mem.eql(u8, dir_one.name.value, "auth"));
    try std.testing.expect(dir_one.arguments == null);

    const dir_two = obj_def.directives.?[1];
    try std.testing.expect(std.mem.eql(u8, dir_two.name.value, "cached"));
    try std.testing.expect(dir_two.arguments != null);
    try std.testing.expect(dir_two.arguments.?.len == 1);
}

test "should parse directives on field definition" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const source =
        \\ type User {
        \\   email: String @deprecated(reason: "Use emailAddress")
        \\ }
    ;
    var p = Parser.init(allocator, source, .{});
    const doc = try p.parse();

    const obj_def = doc.definitions[0].TypeSystemDefinition.TypeDefinition.ObjectTypeDefinition;
    const field = obj_def.fields.?[0];

    try std.testing.expect(std.mem.eql(u8, field.name.value, "email"));
    try std.testing.expect(field.directives != null);
    try std.testing.expect(field.directives.?.len == 1);

    const directive = field.directives.?[0];
    try std.testing.expect(std.mem.eql(u8, directive.name.value, "deprecated"));
    try std.testing.expect(directive.arguments != null);
    try std.testing.expect(directive.arguments.?.len == 1);
    try std.testing.expect(std.mem.eql(u8, directive.arguments.?[0].name.value, "reason"));
}
