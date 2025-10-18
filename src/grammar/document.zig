const std = @import("std");
const ast = @import("ast.zig");
const Parser = @import("../core/parser.zig").Parser;
const TokenKind = @import("../core/tokens.zig").TokenKind;

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

    while (true) {
        const def = try parseDefinition(p);
        try nodes.append(def);

        if (try p.expectOptionalToken(TokenKind.Eof)) {
            break;
        }
    }
    return try nodes.toOwnedSlice();
}

pub fn parseDefinition(p: *Parser) !ast.DefinitionNode {
    p.debug("parseDefinition");
    var token = try p.peek();
    if (token.kind == TokenKind.StringValue) {
        token = try p.lookahead();
    }

    const keyword = ast.stringToKeyword(token.data) orelse return error.UnknownKeyword;
    switch (keyword) {
        ast.SyntaxKeyWord.Schema => {
            const def = try parseSchemaDefinition(p);
            return ast.DefinitionNode{
                .TypeSystemDefinition = ast.TypeSystemDefinitionNode{
                    .SchemaDefinition = def,
                },
            };
        },
        ast.SyntaxKeyWord.Scalar => {
            const def = try parseScalarTypeDefinition(p);
            return ast.DefinitionNode{
                .TypeSystemDefinition = ast.TypeSystemDefinitionNode{
                    .TypeDefinition = ast.TypeDefinitionNode{
                        .ScalarTypeDefinition = def,
                    },
                },
            };
        },
        ast.SyntaxKeyWord.Type => {
            const def = try parseObjectTypeDefinition(p);
            return ast.DefinitionNode{
                .TypeSystemDefinition = ast.TypeSystemDefinitionNode{
                    .TypeDefinition = ast.TypeDefinitionNode{
                        .ObjectTypeDefinition = def,
                    },
                },
            };
        },
        ast.SyntaxKeyWord.Interface => {
            const def = try parseInterfaceTypeDefinition(p);
            return ast.DefinitionNode{
                .TypeSystemDefinition = ast.TypeSystemDefinitionNode{
                    .TypeDefinition = ast.TypeDefinitionNode{
                        .InterfaceTypeDefinition = def,
                    },
                },
            };
        },
        ast.SyntaxKeyWord.Union => {
            const def = try parseUnionTypeDefinition(p);
            return ast.DefinitionNode{
                .TypeSystemDefinition = ast.TypeSystemDefinitionNode{
                    .TypeDefinition = ast.TypeDefinitionNode{
                        .UnionTypeDefinition = def,
                    },
                },
            };
        },
        ast.SyntaxKeyWord.Enum => {
            const def = try parseEnumTypeDefinition(p);
            return ast.DefinitionNode{
                .TypeSystemDefinition = ast.TypeSystemDefinitionNode{
                    .TypeDefinition = ast.TypeDefinitionNode{
                        .EnumTypeDefinition = def,
                    },
                },
            };
        },
        ast.SyntaxKeyWord.Input => {
            const def = try parseInputObjectTypeDefinition(p);
            return ast.DefinitionNode{
                .TypeSystemDefinition = ast.TypeSystemDefinitionNode{
                    .TypeDefinition = ast.TypeDefinitionNode{
                        .InputObjectTypeDefinition = def,
                    },
                },
            };
        },
        ast.SyntaxKeyWord.Directive => {
            const def = try parseDirectiveDefinition(p);
            return ast.DefinitionNode{
                .TypeSystemDefinition = ast.TypeSystemDefinitionNode{ .DirectiveDefinition = def },
            };
        },
        ast.SyntaxKeyWord.Query, ast.SyntaxKeyWord.Mutation, ast.SyntaxKeyWord.Subscription, ast.SyntaxKeyWord.LCurly => {
            const def = try parseOperationDefinition(p);
            return ast.DefinitionNode{
                .ExecutableDefinition = ast.ExecutableDefinitionNode{
                    .OperationDefinition = def,
                },
            };
        },
        ast.SyntaxKeyWord.Fragment => {
            const def = try parseFragmentDefinition(p);
            return ast.DefinitionNode{
                .ExecutableDefinition = ast.ExecutableDefinitionNode{
                    .FragmentDefinition = def,
                },
            };
        },
        ast.SyntaxKeyWord.Extend => {
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
