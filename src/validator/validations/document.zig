const std = @import("std");
const ast = @import("../../grammar/ast.zig");
const ValidationContext = @import("../validation_context.zig").ValidationContext;

const validateOperation = @import("./operation.zig").validateOperation;
const validateSubscription = @import("./operation.zig").validateSubscription;
const validateFragmentDefinition = @import("./fragment.zig").validateFragmentDefinition;
const checkUnusedFragments = @import("./fragment.zig").checkUnusedFragments;
const validateInputObjectDefinition = @import("./input.zig").validateInputObjectDefinition;
const validateInputObjectExtension = @import("./input.zig").validateInputObjectExtension;
const validateArgumentDefinitions = @import("./input.zig").validateArgumentDefinitions;
const validateFieldDefinitions = @import("./field.zig").validateFieldDefinitions;
const validateScalarDefinition = @import("./scalar.zig").validateScalarDefinition;
const validateUnionDefinition = @import("./union.zig").validateUnionDefinition;
const validateEnumDefinition = @import("./enum.zig").validateEnumDefinition;
const validateEnumExtension = @import("./enum.zig").validateEnumExtension;
const validateDirectives = @import("./directive.zig").validateDirectives;

pub fn validateDocument(ctx: *ValidationContext, doc: ast.DocumentNode) !void {
    // TODO: graphql-js does the walk in a single pass. optimize later.
    // the visitor per rule pattern is very readable, but the implementation isnt very ziggy.

    // fragment pass
    for (doc.definitions) |def| {
        switch (def) {
            .ExecutableDefinition => |ex| switch (ex) {
                .FragmentDefinition => |frag| {
                    const name = frag.name.value;
                    if (ctx.fragment_defs.contains(name)) {
                        // UniqueFragmentNamesRule
                        try ctx.addError(.DuplicateFragmentName);
                    } else {
                        try ctx.fragment_defs.put(name, frag);
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
                .FragmentDefinition => |frag| try validateFragmentDefinition(ctx, frag),
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
            try ctx.addError(.MultipleAnonymousOperations);
        }
    }

    // NoUnusedFragmentsRule
    try checkUnusedFragments(ctx, doc);

    // subscription validation pass
    for (doc.definitions) |def| {
        switch (def) {
            .ExecutableDefinition => |ex| switch (ex) {
                .OperationDefinition => |op| try validateSubscription(ctx, op),
                else => {},
            },
            else => {},
        }
    }
}

pub fn validateSchema(ctx: *ValidationContext, doc: ast.DocumentNode) !void {
    for (doc.definitions) |def| {
        switch (def) {
            .TypeSystemDefinition => |type_sys_def| {
                try validateTypeSystemDefinition(ctx, type_sys_def);
            },
            .TypeSystemExtension => |type_sys_ext| {
                try validateTypeSystemExtension(ctx, type_sys_ext);
            },
            .ExecutableDefinition => {},
        }
    }
}

fn validateTypeSystemDefinition(ctx: *ValidationContext, def: ast.TypeSystemDefinitionNode) !void {
    switch (def) {
        .TypeDefinition => |type_def| try validateTypeDefinition(ctx, type_def),
        .SchemaDefinition => |schema_def| {
            try validateDirectives(ctx, schema_def.directives, .Schema);
        },
        .DirectiveDefinition => |dir_def| {
            // ReservedNameRule
            try validateTypeSystemName(ctx, dir_def.name.value);

            // UniqueInputFieldNamesRule, directive arguments must have unique names
            if (dir_def.arguments) |args| {
                try validateArgumentDefinitions(ctx, args);
            }
        },
    }
}

fn validateTypeDefinition(ctx: *ValidationContext, type_def: ast.TypeDefinitionNode) !void {
    // ReservedNameRule
    const name = switch (type_def) {
        .ScalarTypeDefinition => |d| d.name.value,
        .ObjectTypeDefinition => |d| d.name.value,
        .InterfaceTypeDefinition => |d| d.name.value,
        .UnionTypeDefinition => |d| d.name.value,
        .EnumTypeDefinition => |d| d.name.value,
        .InputObjectTypeDefinition => |d| d.name.value,
    };
    try validateTypeSystemName(ctx, name);

    switch (type_def) {
        .InputObjectTypeDefinition => |input| try validateInputObjectDefinition(ctx, input),
        .ObjectTypeDefinition => |obj| {
            try validateDirectives(ctx, obj.directives, .Object);
            if (obj.fields) |fields| {
                try validateFieldDefinitions(ctx, fields);
            }
        },
        .InterfaceTypeDefinition => |iface| {
            try validateDirectives(ctx, iface.directives, .Interface);
            if (iface.fields) |fields| {
                try validateFieldDefinitions(ctx, fields);
            }
        },
        .ScalarTypeDefinition => |scalar| try validateScalarDefinition(ctx, scalar),
        .UnionTypeDefinition => |union_def| try validateUnionDefinition(ctx, union_def),
        .EnumTypeDefinition => |enum_def| try validateEnumDefinition(ctx, enum_def),
    }
}

fn validateTypeSystemName(ctx: *ValidationContext, name: []const u8) !void {
    if (std.mem.startsWith(u8, name, "__")) {
        try ctx.addError(.ReservedName);
    }
}

fn validateTypeSystemExtension(ctx: *ValidationContext, ext: ast.TypeSystemExtensionNode) !void {
    switch (ext) {
        .SchemaExtension => {
            // TODO: validate schema extension
        },
        .TypeExtension => |type_ext| try validateTypeExtension(ctx, type_ext),
    }
}

fn validateTypeExtension(ctx: *ValidationContext, type_ext: ast.TypeExtensionNode) !void {
    switch (type_ext) {
        .InputObjectTypeExtension => |input_ext| try validateInputObjectExtension(ctx, input_ext),
        .ObjectTypeExtension => |obj_ext| {
            if (obj_ext.fields) |fields| {
                try validateFieldDefinitions(ctx, fields);
            }
        },
        .InterfaceTypeExtension => |iface_ext| {
            if (iface_ext.fields) |fields| {
                try validateFieldDefinitions(ctx, fields);
            }
        },
        .ScalarTypeExtension => {
            // TODO: validate scalar extension
        },
        .UnionTypeExtension => {
            // TODO: validate union extension
        },
        .EnumTypeExtension => |enum_ext| try validateEnumExtension(ctx, enum_ext),
    }
}
