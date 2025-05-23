const std = @import("std");
const ast = @import("ast.zig");
const Parser = @import("../parser.zig").Parser;
const TokenKind = @import("../lib/tokens.zig").TokenKind;

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
    const typeNode = try p.allocator.create(ast.TypeNode);

    if (p.expectOptionalToken(TokenKind.LBracket)) {
        const innerType = try parseTypeReference(p);
        _ = try p.expect(TokenKind.RBracket);

        typeNode.* = ast.TypeNode{
            .ListType = ast.ListTypeNode{
                .type = innerType,
            },
        };
    } else {
        const name = try parseNamedType(p);
        typeNode.* = ast.TypeNode{ .NamedType = name };
    }

    if (p.expectOptionalToken(TokenKind.Bang)) {
        const non_null = try p.allocator.create(ast.TypeNode);
        non_null.* = ast.TypeNode{
            .NonNullType = ast.NonNullTypeNode{
                .type = typeNode,
            },
        };
        return non_null;
    }

    return typeNode;
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
    const token = p.lookahead() orelse return error.UnexpectedNullToken;

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
