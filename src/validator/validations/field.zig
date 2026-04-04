const std = @import("std");
const ast = @import("../../grammar/ast.zig");
const schema_mod = @import("../schema.zig");
const ValidationContext = @import("../validation_context.zig").ValidationContext;

const validateArguments = @import("./argument.zig").validateArguments;
const validateDirectives = @import("./directive.zig").validateDirectives;
const validateSelectionSet = @import("./selection.zig").validateSelectionSet;
const validateArgumentDefinitions = @import("./input.zig").validateArgumentDefinitions;
const validateValues = @import("./value.zig").validateValues;
const validateVariableUsage = @import("./variable.zig").validateVariableUsage;

pub fn validateField(ctx: *ValidationContext, field: ast.FieldNode, parent_type_name: ?[]const u8) anyerror!void {
    // first do all the validation that we can without knowing the type of the field.
    try validateDirectives(ctx, field.directives, .Field);
    try validateArguments(ctx, field.arguments);

    // if we don't know the type (no schema, or invalid parent), we cannot perform
    // type-aware checks for this field. However, for standalone executable validation
    // we still want to traverse into the nested selection set so that validations
    // that do not require a schema (like missing fragment detection) can run.
    const type_name = parent_type_name orelse {
        if (field.selection_set) |nested| {
            try validateSelectionSet(ctx, nested, null);
        }
        return;
    };

    // FieldsOnCorrectTypeRule
    const field_def = checkFieldExistence(ctx, type_name, field.name.value) catch {
        if (field.selection_set) |nested| {
            try validateSelectionSet(ctx, nested, null);
        }
        return;
    };

    try validateFieldArgumentTypes(ctx, field, field_def);
    try checkRequiredFieldArguments(ctx, field, field_def);
    try validateLeafFieldSelection(ctx, field, type_name, field_def);

    if (field.selection_set) |nested| {
        const nested_type = resolveFieldReturnType(field_def);
        try validateSelectionSet(ctx, nested, nested_type);
    }
}

pub fn validateFieldDefinition(ctx: *ValidationContext, field_def: ast.FieldDefinitionNode) anyerror!void {
    // TODO: try validateTypeSystemName(ctx, field_def.name, "");
    try validateDirectives(ctx, field_def.directives, .FieldDefinition);
    if (field_def.arguments) |args| {
        try validateArgumentDefinitions(ctx, args);
    }
}

pub fn validateFieldDefinitions(ctx: *ValidationContext, fields: []const ast.FieldDefinitionNode) anyerror!void {
    for (fields) |field_def| {
        try validateFieldDefinition(ctx, field_def);
        // TODO: // Field types in Object Types must be of output type
    }
}

pub fn validateLeafFieldSelection(ctx: *ValidationContext, field: ast.FieldNode, parent_type_name: []const u8, field_def: ast.FieldDefinitionNode) anyerror!void {
    _ = parent_type_name;
    const return_type_name = resolveFieldReturnType(field_def) orelse return;
    const type_info = ctx.schema.getType(return_type_name) orelse return;

    const is_leaf = field.selection_set == null;

    switch (type_info) {
        .Object, .Interface, .Union => {
            if (is_leaf) {
                try ctx.addError(.MissingSubselection);
            }
        },
        .Scalar => {
            if (!is_leaf) {
                try ctx.addError(.SubselectionOnScalarType);
            }
        },
        .Enum => {
            if (!is_leaf) {
                try ctx.addError(.SubselectionOnEnumType);
            }
        },
        .InputObject => {
            // InputObject as a field return type is a schema-level error,
            // not an executable-level error. Handled by schema validation.
        },
    }
}

fn checkFieldExistence(ctx: *ValidationContext, type_name: []const u8, field_name: []const u8) !ast.FieldDefinitionNode {
    return ctx.schema.typeField(type_name, field_name) catch {
        return error.NoSuchField;
    };
}

fn validateFieldArgumentTypes(ctx: *ValidationContext, field: ast.FieldNode, field_def: ast.FieldDefinitionNode) !void {
    const args = field.arguments orelse return;
    const arg_defs = field_def.arguments orelse {
        for (args) |_| {
            try ctx.addError(.UndefinedArgument);
        }
        return;
    };

    for (args) |arg| {
        if (findArgumentDefinition(arg_defs, arg.name.value)) |arg_def| {
            // TODO: pass var_defs from operation context when available
            _ = validateVariableUsage(ctx, arg_def, arg, null);

            // TODO: validate value is of correct type for the argument definition
            // This will call into value.zig with the arg_def.type and arg.value
            // to perform deep type checking (int coercion, enum validation, etc.)
            // TODO: pass var_defs from operation context when available
            try validateValues(ctx, arg_def, arg, null);
        } else {
            try ctx.addError(.UndefinedArgument);
        }
    }
}

fn checkRequiredFieldArguments(ctx: *ValidationContext, field: ast.FieldNode, field_def: ast.FieldDefinitionNode) !void {
    const arg_defs = field_def.arguments orelse return;

    for (arg_defs) |arg_def| {
        if (!isArgumentRequired(arg_def)) continue;

        const is_provided = if (field.arguments) |args| blk: {
            for (args) |arg| {
                if (std.mem.eql(u8, arg.name.value, arg_def.name.value)) {
                    // TODO: also check if the provided value is explicitly null
                    // `requiredArg: null` should still be an error
                    break :blk true;
                }
            }
            break :blk false;
        } else false;

        if (!is_provided) {
            try ctx.addError(.RequiredArgument);
        }
    }
}

fn resolveFieldReturnType(field_def: ast.FieldDefinitionNode) ?[]const u8 {
    return innerNamedType(field_def.type);
}

fn innerNamedType(type_node: *const ast.TypeNode) ?[]const u8 {
    return switch (type_node.*) {
        .NamedType => |named| named.name.value,
        .ListType => |list| innerNamedType(list.type),
        .NonNullType => |non_null| innerNamedType(non_null.type),
    };
}

fn findArgumentDefinition(arg_defs: []const ast.InputValueDefinitionNode, name: []const u8) ?ast.InputValueDefinitionNode {
    for (arg_defs) |arg_def| {
        if (std.mem.eql(u8, arg_def.name.value, name)) {
            return arg_def;
        }
    }
    return null;
}

fn isArgumentRequired(arg_def: ast.InputValueDefinitionNode) bool {
    const has_default = arg_def.default_value != null;
    if (has_default) return false;

    return switch (arg_def.type.*) {
        .NonNullType => true,
        .NamedType, .ListType => false,
    };
}
