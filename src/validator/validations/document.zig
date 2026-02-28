const std = @import("std");
const ast = @import("../../grammar/ast.zig");
const ValidationContext = @import("../validation_context.zig").ValidationContext;

const validateOperation = @import("./operation.zig").validateOperation;
const validateFragment = @import("./fragment.zig").validateFragment;

pub fn validateDocument(ctx: *ValidationContext, doc: ast.DocumentNode) !void {
    // TODO: graphql-js does the walk in a single pass. optimize later.
    // the visitor per rule pattern is very readable, but the implementation isnt very ziggy.
    // collect all fragment definition names
    // this is to find undefined fragments even when a spread appears before its corresponding fragment definition
    // and do other things maybe.
    for (doc.definitions) |def| {
        switch (def) {
            .ExecutableDefinition => |ex| switch (ex) {
                .FragmentDefinition => |frag| {
                    const name = frag.name.value;
                    if (ctx.fragment_names.contains(name)) {
                        // UniqueFragmentNamesRule
                        try ctx.addError(.DuplicateFragmentName);
                    } else {
                        try ctx.fragment_names.put(name, {});
                    }
                },
                else => {},
            },
            else => {},
        }
    }

    // validation pass
    for (doc.definitions) |def| {
        switch (def) {
            .ExecutableDefinition => |ex| switch (ex) {
                .OperationDefinition => |op| try validateOperation(ctx, op),
                .FragmentDefinition => |frag| try validateFragment(ctx, frag),
            },
            .TypeSystemDefinition, .TypeSystemExtension => {
                try ctx.addError(.NonExecutableDefinition);
            },
        }
    }

    // LoneAnonymousOperationRule
    if (ctx.anonymous_operation_count > 0 and ctx.operation_count > 1) {
        var i: u32 = 0;
        while (i < ctx.anonymous_operation_count) : (i += 1) {
            try ctx.addError(.ManyAnonymousOperations);
        }
    }
}
