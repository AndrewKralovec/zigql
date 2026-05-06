const std = @import("std");
const ast = @import("../../ast/ast.zig");
const Parser = @import("../parser.zig").Parser;
const TokenKind = @import("../../lexer/tokens.zig").TokenKind;

const parseNamedType = @import("./type.zig").parseNamedType;
const parseDirectives = @import("./directive.zig").parseDirectives;
const parseSelectionSet = @import("./selection.zig").parseSelectionSet;
const parseName = @import("./name.zig").parseName;

pub fn parseFragmentDefinition(p: *Parser) !ast.FragmentDefinitionNode {
    p.debug("parseFragmentDefinition");
    try p.expectKeyword(ast.SyntaxKeyWord.Fragment);

    const name = try parseFragmentName(p);

    try p.expectKeyword(ast.SyntaxKeyWord.On);
    const type_condition = try parseNamedType(p);
    const directives = try parseDirectives(p, false);
    const selection_set = try parseSelectionSet(p);

    return ast.FragmentDefinitionNode{
        .name = name,
        .type_condition = type_condition,
        .directives = directives,
        .selection_set = selection_set,
    };
}

pub fn parseFragmentName(p: *Parser) !ast.NameNode {
    p.debug("parseFragmentName");
    const token = try p.peek();
    // TODO: Keyword check eats the token. Use an if statement instead. Come back to this later.
    if (std.mem.eql(u8, token.data, "on")) {
        return error.UnexpectedFragmentName;
    }

    const name = try parseName(p);
    return name;
}

//
// Test cases for fragment
//

test "should parse a fragment definition" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const source =
        \\ fragment UserFragment on User {
        \\   id
        \\   name
        \\ }
    ;
    var p = Parser.init(allocator, source, .{});
    const doc = try p.parse();
    try std.testing.expect(doc.definitions.len == 1);

    const dn = doc.definitions[0];
    try std.testing.expect(dn == ast.DefinitionNode.ExecutableDefinition);

    const def = dn.ExecutableDefinition;
    try std.testing.expect(def == ast.ExecutableDefinitionNode.FragmentDefinition);

    const frag_def = def.FragmentDefinition;
    try std.testing.expect(std.mem.eql(u8, frag_def.name.value, "UserFragment"));

    try std.testing.expect(std.mem.eql(u8, frag_def.type_condition.name.value, "User"));
    try std.testing.expect(frag_def.selection_set.selections.len == 2);

    const sel_one = frag_def.selection_set.selections[0];
    try std.testing.expect(sel_one == ast.SelectionNode.Field);

    const f_one = sel_one.Field;
    try std.testing.expect(std.mem.eql(u8, f_one.name.value, "id"));

    const sel_two = frag_def.selection_set.selections[1];
    try std.testing.expect(sel_two == ast.SelectionNode.Field);

    const f_two = sel_two.Field;
    try std.testing.expect(std.mem.eql(u8, f_two.name.value, "name"));
}
