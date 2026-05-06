const std = @import("std");
const ast = @import("../../ast/ast.zig");
const Parser = @import("../parser.zig").Parser;
const TokenKind = @import("../../lexer/tokens.zig").TokenKind;

const parseName = @import("./name.zig").parseName;
const parseSchemaExtension = @import("./schema.zig").parseSchemaExtension;
const parseScalarTypeExtension = @import("./scalar.zig").parseScalarTypeExtension;
const parseObjectTypeExtension = @import("./object.zig").parseObjectTypeExtension;
const parseInterfaceTypeExtension = @import("./interface.zig").parseInterfaceTypeExtension;
const parseUnionTypeExtension = @import("./union.zig").parseUnionTypeExtension;
const parseEnumTypeExtension = @import("./enum.zig").parseEnumTypeExtension;
const parseInputObjectTypeExtension = @import("./input.zig").parseInputObjectTypeExtension;

pub fn parseTypeReference(p: *Parser) !*ast.TypeNode {
    p.debug("parseTypeReference");
    // GraphQL types can be nested like [String!]! or [[ID]]. each layer needs its own allocation.
    // We recursively build this structure but need to clean up if anything fails along the way.
    const type_node = try p.allocator.create(ast.TypeNode);
    errdefer p.allocator.destroy(type_node);

    if (try p.expectOptionalToken(TokenKind.LBracket)) {
        const inner_type = parseTypeReference(p) catch |err| {
            return err;
        };
        _ = p.expect(TokenKind.RBracket) catch |err| {
            inner_type.deinit(p.allocator);
            p.allocator.destroy(inner_type);
            return err;
        };

        type_node.* = ast.TypeNode{
            .ListType = ast.ListTypeNode{
                .type = inner_type,
            },
        };
    } else {
        const name = parseNamedType(p) catch |err| {
            return err;
        };
        type_node.* = ast.TypeNode{ .NamedType = name };
    }

    if (try p.expectOptionalToken(TokenKind.Bang)) {
        const non_null = p.allocator.create(ast.TypeNode) catch |err| {
            type_node.deinit(p.allocator);
            return err;
        };
        non_null.* = ast.TypeNode{
            .NonNullType = ast.NonNullTypeNode{
                .type = type_node,
            },
        };
        return non_null;
    }

    return type_node;
}

pub fn parseNamedType(p: *Parser) !ast.NamedTypeNode {
    p.debug("parseNamedType");
    const name = try parseName(p);
    return ast.NamedTypeNode{
        .name = name,
    };
}

pub fn parseTypeSystemExtension(p: *Parser) !ast.TypeSystemExtensionNode {
    p.debug("parseTypeSystemExtension");
    const token = try p.lookahead();

    if (token.kind == TokenKind.Name) {
        const keyword = ast.stringToKeyword(token.data) orelse return error.UnknownKeyword;
        switch (keyword) {
            ast.SyntaxKeyWord.Schema => {
                return ast.TypeSystemExtensionNode{
                    .SchemaExtension = try parseSchemaExtension(p),
                };
            },
            ast.SyntaxKeyWord.Scalar => {
                return ast.TypeSystemExtensionNode{
                    .TypeExtension = ast.TypeExtensionNode{
                        .ScalarTypeExtension = try parseScalarTypeExtension(p),
                    },
                };
            },
            ast.SyntaxKeyWord.Type => {
                return ast.TypeSystemExtensionNode{
                    .TypeExtension = ast.TypeExtensionNode{
                        .ObjectTypeExtension = try parseObjectTypeExtension(p),
                    },
                };
            },
            ast.SyntaxKeyWord.Interface => {
                return ast.TypeSystemExtensionNode{
                    .TypeExtension = ast.TypeExtensionNode{
                        .InterfaceTypeExtension = try parseInterfaceTypeExtension(p),
                    },
                };
            },
            ast.SyntaxKeyWord.Union => {
                return ast.TypeSystemExtensionNode{
                    .TypeExtension = ast.TypeExtensionNode{
                        .UnionTypeExtension = try parseUnionTypeExtension(p),
                    },
                };
            },
            ast.SyntaxKeyWord.Enum => {
                return ast.TypeSystemExtensionNode{
                    .TypeExtension = ast.TypeExtensionNode{
                        .EnumTypeExtension = try parseEnumTypeExtension(p),
                    },
                };
            },
            ast.SyntaxKeyWord.Input => {
                return ast.TypeSystemExtensionNode{
                    .TypeExtension = ast.TypeExtensionNode{
                        .InputObjectTypeExtension = try parseInputObjectTypeExtension(p),
                    },
                };
            },
            else => {
                return error.UnexpectedToken;
            },
        }
    }
    return error.UnexpectedToken;
}

//
// Test cases for type
//

test "should parse a named type reference" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const source =
        \\ type User {
        \\   name: String
        \\ }
    ;
    var p = Parser.init(allocator, source, .{});
    const doc = try p.parse();

    const type_def = doc.definitions[0].TypeSystemDefinition.TypeDefinition.ObjectTypeDefinition;
    const field = type_def.fields.?[0];
    try std.testing.expect(std.mem.eql(u8, field.name.value, "name"));

    const type_node = field.type.*;
    try std.testing.expect(type_node == ast.TypeNode.NamedType);
    try std.testing.expect(std.mem.eql(u8, type_node.NamedType.name.value, "String"));
}

test "should parse a non-null list type reference" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const source =
        \\ type User {
        \\   tags: [String!]!
        \\ }
    ;
    var p = Parser.init(allocator, source, .{});
    const doc = try p.parse();

    const type_def = doc.definitions[0].TypeSystemDefinition.TypeDefinition.ObjectTypeDefinition;
    const field = type_def.fields.?[0];
    try std.testing.expect(std.mem.eql(u8, field.name.value, "tags"));

    const outer = field.type.*;
    try std.testing.expect(outer == ast.TypeNode.NonNullType);

    const list = outer.NonNullType.type.*;
    try std.testing.expect(list == ast.TypeNode.ListType);

    const inner_non_null = list.ListType.type.*;
    try std.testing.expect(inner_non_null == ast.TypeNode.NonNullType);

    const named = inner_non_null.NonNullType.type.*;
    try std.testing.expect(named == ast.TypeNode.NamedType);
    try std.testing.expect(std.mem.eql(u8, named.NamedType.name.value, "String"));
}
