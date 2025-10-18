const std = @import("std");
const ast = @import("ast.zig");
const Parser = @import("../parser.zig").Parser;
const TokenKind = @import("../lib/tokens.zig").TokenKind;

const parseField = @import("./field.zig").parseField;
const parseFragmentName = @import("./fragment.zig").parseFragmentName;
const parseDirectives = @import("./directive.zig").parseDirectives;
const parseNamedType = @import("./type.zig").parseNamedType;

pub fn parseSelectionSet(p: *Parser) anyerror!ast.SelectionSetNode {
    p.debug("parseSelectionSet");
    const selections = try parseSelections(p);
    const node = ast.SelectionSetNode{
        .selections = selections,
    };
    return node;
}

pub fn parseSelections(p: *Parser) ![]ast.SelectionNode {
    p.debug("parseSelections");
    var nodes = std.ArrayList(ast.SelectionNode).init(p.allocator);
    defer nodes.deinit();

    _ = try p.expect(TokenKind.LCurly);
    while (p.peek()) |_| {
        const sel = try parseSelection(p);
        try nodes.append(sel);

        if (try p.expectOptionalToken(TokenKind.RCurly)) {
            break;
        }
    }
    return nodes.toOwnedSlice();
}

pub fn parseSelection(p: *Parser) !ast.SelectionNode {
    p.debug("parseSelection");
    const token = p.peek() orelse return error.UnexpectedNullToken;
    // Field.
    if (token.kind != TokenKind.Spread) {
        const field = try parseField(p);
        return ast.SelectionNode{ .Field = field };
    }

    // Fragment spread.
    _ = try p.expect(TokenKind.Spread);
    const hasTypeCondition = try p.expectOptionalKeyword(ast.SyntaxKeyWord.On);
    if (!hasTypeCondition and p.peekKind(TokenKind.Name)) {
        const name = try parseFragmentName(p);
        const directives = try parseDirectives(p, false);
        return ast.SelectionNode{
            .FragmentSpread = ast.FragmentSpreadNode{
                .name = name,
                .directives = directives,
            },
        };
    }

    // Inline Fragment.
    var typeCondition: ?ast.NamedTypeNode = null;
    if (hasTypeCondition) {
        typeCondition = try parseNamedType(p);
    }

    const directives = try parseDirectives(p, false);
    const selectionSet = try parseSelectionSet(p);

    return ast.SelectionNode{
        .InlineFragment = ast.InlineFragmentNode{
            .typeCondition = typeCondition,
            .directives = directives,
            .selectionSet = selectionSet,
        },
    };
}
