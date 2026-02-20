const std = @import("std");
const ast = @import("../grammar/ast.zig");
const ValidationContext = @import("validation_context.zig").ValidationContext;

const document_checks = @import("checks/document.zig");
const operations_checks = @import("checks/operations.zig");

pub fn validateDocument(ctx: *ValidationContext, doc: ast.DocumentNode) !void {
    try document_checks.checkExecutableDefinitions(ctx, doc.definitions);
    try operations_checks.checkLoneAnonymousOperation(ctx, doc.definitions);
    try operations_checks.checkUniqueOperationNames(ctx, doc.definitions);
}
