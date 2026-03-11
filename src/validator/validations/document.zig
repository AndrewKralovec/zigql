const std = @import("std");
const ast = @import("../../grammar/ast.zig");
const ValidationContext = @import("../validation_context.zig").ValidationContext;

const validateOperation = @import("./operation.zig").validateOperation;
const validateFragment = @import("./fragment.zig").validateFragment;
const checkUnusedFragments = @import("./fragment.zig").checkUnusedFragments;
const validateInputObjectDefinition = @import("./input.zig").validateInputObjectDefinition;
const validateInputObjectExtension = @import("./input.zig").validateInputObjectExtension;
const validateArgumentDefinitions = @import("./input.zig").validateArgumentDefinitions;
const validateFieldDefinitions = @import("./field.zig").validateFieldDefinitions;
const validateScalarDefinition = @import("./scalar.zig").validateScalarDefinition;
const validateUnionDefinition = @import("./union.zig").validateUnionDefinition;

pub fn validateDocument(ctx: *ValidationContext, doc: ast.DocumentNode) !void {
    // TODO: graphql-js does the walk in a single pass. optimize later.
    // the visitor per rule pattern is very readable, but the implementation isnt very ziggy.
    // collect all fragment definition names
    // this is to find undefined fragments even when a spread appears before its corresponding fragment definition
    // and do other things maybe.

    var fragment_defs = std.StringHashMap(ast.FragmentDefinitionNode).init(ctx.allocator);
    defer fragment_defs.deinit();

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
                        try fragment_defs.put(name, frag);
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

    // NoUnusedFragmentsRule
    try checkUnusedFragments(ctx, doc, &fragment_defs);
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
        .SchemaDefinition => {
            // TODO: validate schema definition
        },
        .DirectiveDefinition => |dir_def| {
            // UniqueInputFieldNamesRule, directive arguments must have unique names
            if (dir_def.arguments) |args| {
                try validateArgumentDefinitions(ctx, args);
            }
        },
    }
}

fn validateTypeDefinition(ctx: *ValidationContext, type_def: ast.TypeDefinitionNode) !void {
    switch (type_def) {
        .InputObjectTypeDefinition => |input| try validateInputObjectDefinition(ctx, input),
        .ObjectTypeDefinition => |obj| {
            if (obj.fields) |fields| {
                try validateFieldDefinitions(ctx, fields);
            }
        },
        .InterfaceTypeDefinition => |iface| {
            if (iface.fields) |fields| {
                try validateFieldDefinitions(ctx, fields);
            }
        },
        .ScalarTypeDefinition => |scalar| try validateScalarDefinition(ctx, scalar),
        .UnionTypeDefinition => |union_def| try validateUnionDefinition(ctx, union_def),
        .EnumTypeDefinition => {
            // TODO: validate enum definition
        },
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
        .EnumTypeExtension => {
            // TODO: validate enum extension
        },
    }
}
