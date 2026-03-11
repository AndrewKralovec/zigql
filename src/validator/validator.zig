const std = @import("std");
const ast = @import("../grammar/ast.zig");

const ValidationError = @import("errors.zig").ValidationError;
const ValidationContext = @import("./validation_context.zig").ValidationContext;
const Schema = @import("./schema.zig").Schema;
const validate = @import("./validate.zig");

pub const Validator = struct {
    allocator: std.mem.Allocator,
    schema: *const Schema,

    pub fn init(
        allocator: std.mem.Allocator,
        schema: *const Schema,
    ) Validator {
        return Validator{
            .allocator = allocator,
            .schema = schema,
        };
    }

    pub fn validateQuery(self: *Validator, document: ast.DocumentNode) ![]ValidationError {
        var context = ValidationContext.init(self.allocator, self.schema);
        defer context.deinit();

        try validate.validateDocument(&context, document);

        return try context.errors.toOwnedSlice();
    }

    pub fn validateSchema(self: *Validator, document: ast.DocumentNode) ![]ValidationError {
        var context = ValidationContext.init(self.allocator, self.schema);
        defer context.deinit();

        try validate.validateSchema(&context, document);

        return try context.errors.toOwnedSlice();
    }
};

pub fn validateQuery(allocator: std.mem.Allocator, schema: *const Schema, document: ast.DocumentNode) ![]ValidationError {
    var validator = Validator.init(allocator, schema);
    return try validator.validateQuery(document);
}

pub fn validateSchema(allocator: std.mem.Allocator, schema: *const Schema, document: ast.DocumentNode) ![]ValidationError {
    var validator = Validator.init(allocator, schema);
    return try validator.validateSchema(document);
}

//
// Test cases for the validator
//

const parse = @import("../zig_ql.zig").parse;

test "should validate ExecutableDefinitionsRule" {
    const allocator = std.testing.allocator;
    var schema = Schema.init(allocator);
    defer schema.deinit();

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const query_allocator = arena.allocator(); // i dont want to manually free the query nodes
    const query_source =
        \\ query Foo {
        \\   user {
        \\     name
        \\   }
        \\ }
        \\ type User {
        \\   name: String
        \\ }
        \\ extend type Guest {
        \\   role: String
        \\ }
    ;
    const query_doc = try parse(query_allocator, query_source);

    const errors = try validateQuery(allocator, &schema, query_doc);
    defer {
        for (errors) |*err| {
            err.deinit();
        }
        allocator.free(errors);
    }

    try std.testing.expectEqual(@as(usize, 2), errors.len);
}
