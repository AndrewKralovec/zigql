const std = @import("std");
const ast = @import("ast.zig");
const Parser = @import("../parser.zig").Parser;
const TokenKind = @import("../lib/tokens.zig").TokenKind;

const parseSchemaDefinition = @import("./schema.zig").parseSchemaDefinition;
const parseScalarTypeDefinition = @import("./scalar.zig").parseScalarTypeDefinition;
const parseObjectTypeDefinition = @import("./object.zig").parseObjectTypeDefinition;
const parseInterfaceTypeDefinition = @import("./interface.zig").parseInterfaceTypeDefinition;
const parseUnionTypeDefinition = @import("./union.zig").parseUnionTypeDefinition;
const parseEnumTypeDefinition = @import("./enum.zig").parseEnumTypeDefinition;
const parseInputObjectTypeDefinition = @import("./input.zig").parseInputObjectTypeDefinition;
const parseDirectiveDefinition = @import("./directive.zig").parseDirectiveDefinition;
const parseOperationDefinition = @import("./operation.zig").parseOperationDefinition;
const parseFragmentDefinition = @import("./fragment.zig").parseFragmentDefinition;
const parseTypeSystemExtension = @import("./type.zig").parseTypeSystemExtension;

pub fn parseDocument(p: *Parser) !ast.DocumentNode {
    p.debug("parseDocument");
    const definitions = try parseDefinitions(p);
    const node = ast.DocumentNode{
        .kind = ast.SyntaxKind.Document,
        .definitions = definitions,
    };
    return node;
}

pub fn parseDefinitions(p: *Parser) ![]ast.DefinitionNode {
    p.debug("parseDefinitions");
    var nodes = std.ArrayList(ast.DefinitionNode).init(p.allocator);
    defer nodes.deinit();

    while (p.peek()) |_| {
        const def = try parseDefinition(p);
        try nodes.append(def);

        if (p.expectOptionalToken(TokenKind.Eof)) {
            break;
        }
    }
    return try nodes.toOwnedSlice();
}

pub fn parseDefinition(p: *Parser) !ast.DefinitionNode {
    p.debug("parseDefinition");
    var token = p.peek() orelse return error.UnexpectedNullToken;
    if (token.kind == TokenKind.StringValue) {
        token = p.lookahead() orelse return error.UnexpectedNullToken;
    }

    const keyword = ast.stringToKeyword(token.data) orelse return error.UnknownKeyword;
    switch (keyword) {
        ast.SyntaxKeyWord.schema => {
            const def = try parseSchemaDefinition(p);
            return ast.DefinitionNode{
                .TypeSystemDefinition = ast.TypeSystemDefinitionNode{
                    .SchemaDefinition = def,
                },
            };
        },
        ast.SyntaxKeyWord.scalar => {
            const def = try parseScalarTypeDefinition(p);
            return ast.DefinitionNode{
                .TypeSystemDefinition = ast.TypeSystemDefinitionNode{
                    .TypeDefinition = ast.TypeDefinitionNode{
                        .ScalarTypeDefinition = def,
                    },
                },
            };
        },
        ast.SyntaxKeyWord.type => {
            const def = try parseObjectTypeDefinition(p);
            return ast.DefinitionNode{
                .TypeSystemDefinition = ast.TypeSystemDefinitionNode{
                    .TypeDefinition = ast.TypeDefinitionNode{
                        .ObjectTypeDefinition = def,
                    },
                },
            };
        },
        ast.SyntaxKeyWord.interface => {
            const def = try parseInterfaceTypeDefinition(p);
            return ast.DefinitionNode{
                .TypeSystemDefinition = ast.TypeSystemDefinitionNode{
                    .TypeDefinition = ast.TypeDefinitionNode{
                        .InterfaceTypeDefinition = def,
                    },
                },
            };
        },
        ast.SyntaxKeyWord.@"union" => {
            const def = try parseUnionTypeDefinition(p);
            return ast.DefinitionNode{
                .TypeSystemDefinition = ast.TypeSystemDefinitionNode{
                    .TypeDefinition = ast.TypeDefinitionNode{
                        .UnionTypeDefinition = def,
                    },
                },
            };
        },
        ast.SyntaxKeyWord.@"enum" => {
            const def = try parseEnumTypeDefinition(p);
            return ast.DefinitionNode{
                .TypeSystemDefinition = ast.TypeSystemDefinitionNode{
                    .TypeDefinition = ast.TypeDefinitionNode{
                        .EnumTypeDefinition = def,
                    },
                },
            };
        },
        ast.SyntaxKeyWord.input => {
            const def = try parseInputObjectTypeDefinition(p);
            return ast.DefinitionNode{
                .TypeSystemDefinition = ast.TypeSystemDefinitionNode{
                    .TypeDefinition = ast.TypeDefinitionNode{
                        .InputObjectTypeDefinition = def,
                    },
                },
            };
        },
        ast.SyntaxKeyWord.directive => {
            const def = try parseDirectiveDefinition(p);
            return ast.DefinitionNode{
                .TypeSystemDefinition = ast.TypeSystemDefinitionNode{ .DirectiveDefinition = def },
            };
        },
        ast.SyntaxKeyWord.query, ast.SyntaxKeyWord.mutation, ast.SyntaxKeyWord.subscription, ast.SyntaxKeyWord.@"{" => {
            const def = try parseOperationDefinition(p);
            return ast.DefinitionNode{
                .ExecutableDefinition = ast.ExecutableDefinitionNode{
                    .OperationDefinition = def,
                },
            };
        },
        ast.SyntaxKeyWord.fragment => {
            const def = try parseFragmentDefinition(p);
            return ast.DefinitionNode{
                .ExecutableDefinition = ast.ExecutableDefinitionNode{
                    .FragmentDefinition = def,
                },
            };
        },
        ast.SyntaxKeyWord.extend => {
            const def = try parseTypeSystemExtension(p);
            return ast.DefinitionNode{
                .TypeSystemExtension = def,
            };
        },
        else => {
            return error.UnexpectedToken;
        },
    }
}
