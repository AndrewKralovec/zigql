const std = @import("std");
const ast = @import("../grammar/ast.zig");
const ValidationContext = @import("validation_context.zig").ValidationContext;

const document_checks = @import("checks/document.zig");
const operations_checks = @import("checks/operations.zig");
const fragments_checks = @import("checks/fragments.zig");
const variables_checks = @import("checks/variables.zig");

pub fn validateDocument(ctx: *ValidationContext, doc: ast.DocumentNode) !void {
    try document_checks.checkExecutableDefinitions(ctx, doc.definitions);
    try operations_checks.checkLoneAnonymousOperation(ctx, doc.definitions);
    try operations_checks.checkUniqueOperationNames(ctx, doc.definitions);
    try fragments_checks.checkUniqueFragmentNames(ctx, doc.definitions);
    try variables_checks.checkUniqueVariableNames(ctx, doc.definitions);
}
