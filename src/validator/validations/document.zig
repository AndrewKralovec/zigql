const std = @import("std");
const ast = @import("../../grammar/ast.zig");
const ValidationContext = @import("../validation_context.zig").ValidationContext;

const validateOperation = @import("./operation.zig").validateOperation;
const validateFragment = @import("./fragment.zig").validateFragment;

pub fn validateDocument(ctx: *ValidationContext, doc: ast.DocumentNode) !void {
    for (doc.definitions) |def| {
        switch (def) {
            .ExecutableDefinition => |ex| switch (ex) {
                .OperationDefinition => |op| try validateOperation(op),
                .FragmentDefinition => |frag| try validateFragment(frag),
            },
            .TypeSystemDefinition, .TypeSystemExtension => {
                try ctx.addError(.NonExecutableDefinition);
            },
        }
    }
}
