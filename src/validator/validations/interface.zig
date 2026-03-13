const std = @import("std");
const ast = @import("../../grammar/ast.zig");
const ValidationContext = @import("../validation_context.zig").ValidationContext;
const Schema = @import("../schema.zig").Schema;

pub fn validateInterfaceDefinition(ctx: *ValidationContext, schema: Schema) std.mem.Allocator.Error!void {
    _ = ctx;
    _ = schema;
    // TODO: add validation logic
}

pub fn validateImplementsInterfaces(ctx: *ValidationContext, schema: Schema) std.mem.Allocator.Error!void {
    _ = ctx;
    _ = schema;
    // TODO: add validation logic
}
