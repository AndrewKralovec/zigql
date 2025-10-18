const std = @import("std");
const ast = @import("ast.zig");
const Parser = @import("../parser.zig").Parser;
const TokenKind = @import("../lib/tokens.zig").TokenKind;

const parseName = @import("./name.zig").parseName;
const parseVariable = @import("./variable.zig").parseVariable;

pub fn parseValueLiteral(p: *Parser, isConst: bool) anyerror!ast.ValueNode {
    p.debug("parseValueLiteral");
    const token = p.peek() orelse return error.UnexpectedNullToken;

    switch (token.kind) {
        TokenKind.LBracket => {
            const list = try parseList(p, isConst);
            return ast.ValueNode{
                .List = list,
            };
        },
        TokenKind.LCurly => {
            const obj = try parseObject(p, isConst);
            return ast.ValueNode{
                .Object = obj,
            };
        },
        TokenKind.Int => {
            _ = p.pop();
            return ast.ValueNode{
                .Int = ast.IntValueNode{
                    .value = token.data,
                },
            };
        },
        TokenKind.Float => {
            _ = p.pop();
            return ast.ValueNode{
                .Float = ast.FloatValueNode{
                    .value = token.data,
                },
            };
        },
        TokenKind.StringValue => {
            const str = try parseStringLiteral(p);
            return ast.ValueNode{ .String = str };
        },
        TokenKind.Name => {
            _ = p.pop();

            if (std.mem.eql(u8, token.data, "true")) {
                return ast.ValueNode{
                    .Boolean = ast.BooleanValueNode{ .value = true },
                };
            } else if (std.mem.eql(u8, token.data, "false")) {
                return ast.ValueNode{
                    .Boolean = ast.BooleanValueNode{ .value = false },
                };
            } else if (std.mem.eql(u8, token.data, "null")) {
                return ast.ValueNode{
                    .Null = ast.NullValueNode{},
                };
            } else {
                return ast.ValueNode{
                    .Enum = ast.EnumValueNode{
                        .value = token.data,
                    },
                };
            }
        },
        TokenKind.Dollar => {
            if (isConst) {
                _ = try p.expect(TokenKind.Dollar);

                if (p.peekKind(TokenKind.Name)) {
                    return error.UnexpectedVariable;
                } else {
                    return error.UnexpectedToken;
                }
            }

            const variable = try parseVariable(p);
            return ast.ValueNode{ .Variable = variable };
        },
        else => {
            return error.UnexpectedToken;
        },
    }
    return error.UnexpectedToken;
}

pub fn parseConstValueLiteral(p: *Parser) !ast.ValueNode {
    p.debug("parseConstValueLiteral");
    return parseValueLiteral(p, true);
}

pub fn parseList(p: *Parser, isConst: bool) !ast.ListValueNode {
    p.debug("parseList");
    _ = try p.expect(TokenKind.LBracket);

    var nodes = std.ArrayList(ast.ValueNode).init(p.allocator);
    defer nodes.deinit();
    while (!try p.expectOptionalToken(TokenKind.RBracket)) {
        const value = try parseValueLiteral(p, isConst);
        try nodes.append(value);
    }

    return ast.ListValueNode{
        .values = try nodes.toOwnedSlice(),
    };
}

pub fn parseObject(p: *Parser, isConst: bool) !ast.ObjectValueNode {
    p.debug("parseObject");
    _ = try p.expect(TokenKind.LCurly);

    var nodes = std.ArrayList(ast.ObjectFieldNode).init(p.allocator);
    defer nodes.deinit();
    while (!try p.expectOptionalToken(TokenKind.RCurly)) {
        const field = try parseObjectField(p, isConst);
        try nodes.append(field);
    }

    return ast.ObjectValueNode{
        .fields = try nodes.toOwnedSlice(),
    };
}

pub fn parseObjectField(p: *Parser, isConst: bool) !ast.ObjectFieldNode {
    p.debug("parseObjectField");
    const name = try parseName(p);
    _ = try p.expect(TokenKind.Colon);
    const value = try parseValueLiteral(p, isConst);
    return ast.ObjectFieldNode{
        .name = name,
        .value = value,
    };
}

pub fn parseStringLiteral(p: *Parser) !ast.StringValueNode {
    p.debug("parseStringLiteral");
    const token = p.pop() orelse return error.UnexpectedNullToken;
    return ast.StringValueNode{
        .value = token.data,
    };
}
