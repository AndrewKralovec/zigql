const std = @import("std");
const ast = @import("../../grammar/ast.zig");
const ValidationContext = @import("../validation_context.zig").ValidationContext;

const validateDirectives = @import("./directive.zig").validateDirectives;

pub fn validateUnionDefinition(ctx: *ValidationContext, union_def: ast.UnionTypeDefinitionNode) anyerror!void {
    try validateDirectives(ctx, union_def.directives, "UNION");

    if (union_def.types) |members| {
        for (members) |member| {
            try validateUnionMember(ctx, member);
        }
    } else {
        try ctx.addError(.EmptyMemberSet);
    }
}

fn validateUnionMember(ctx: *ValidationContext, member: ast.NamedTypeNode) std.mem.Allocator.Error!void {
    const type_def = ctx.schema.getType(member.name.value);
    if (type_def) |t| {
        switch (t) {
            .Object => {},
            .Scalar, .Interface, .Union, .Enum, .InputObject => {
                try ctx.addError(.UnionMemberObjectType);
            },
        }
    } else {
        try ctx.addError(.UndefinedDefinition);
    }
}
