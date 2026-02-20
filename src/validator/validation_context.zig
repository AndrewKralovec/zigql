const std = @import("std");
const schema = @import("schema.zig");
const ast = @import("../grammar/ast.zig");

const ValidationErrorKind = @import("errors.zig").ValidationErrorKind;
const ValidationError = @import("errors.zig").ValidationError;

pub const ValidationContext = struct {
    schema: *const schema.Schema,
    errors: std.ArrayList(ValidationError),
    allocator: std.mem.Allocator,

    // reusable map for uniqueness checks (arguments, variables, etc etc).
    // clearred via clearRetainingCapacity
    seen_names: std.StringHashMap(bool),

    // doc uniqueness tracking (lives for entire validation)
    operation_names: std.StringHashMap(void),
    fragment_names: std.StringHashMap(void),

    // operation tracking
    operation_count: u32,
    anonymous_operation_count: u32,

    pub fn init(allocator: std.mem.Allocator, schema_ref: *const schema.Schema) ValidationContext {
        return ValidationContext{
            .schema = schema_ref,
            .errors = std.ArrayList(ValidationError).init(allocator),
            .allocator = allocator,

            .seen_names = std.StringHashMap(bool).init(allocator),
            .operation_names = std.StringHashMap(void).init(allocator),
            .fragment_names = std.StringHashMap(void).init(allocator),
            .operation_count = 0,
            .anonymous_operation_count = 0,
        };
    }

    pub fn deinit(self: *ValidationContext) void {
        for (self.errors.items) |*err| {
            err.deinit();
        }
        self.errors.deinit();

        self.seen_names.deinit();
        self.operation_names.deinit();
        self.fragment_names.deinit();
    }

    pub fn addError(self: *ValidationContext, kind: ValidationErrorKind) !void {
        const err = try ValidationError.init(kind);
        try self.errors.append(err);
    }

    pub fn hasErrors(self: *ValidationContext) bool {
        return self.errors.items.len > 0;
    }

    pub fn errorCount(self: *ValidationContext) usize {
        return self.errors.items.len;
    }
};
