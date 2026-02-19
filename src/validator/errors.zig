const std = @import("std");
const Allocator = std.mem.Allocator;

pub const ValidationErrorKind = enum {
    NonExecutableDefinition,
    // TODO: remove later. This is a default error just to let zig build.
    // an enum of one will lead to a division by zero error
    Unknown,
};

// TODO: import the validation object in the future
// for now, let it be a wrapper around the error kind.
// i can just replace ValidationError with the enum, would be easy if i choose.
pub const ValidationError = struct {
    kind: ValidationErrorKind,

    pub fn init(kind: ValidationErrorKind) !ValidationError {
        return ValidationError{ .kind = kind };
    }

    pub fn deinit(self: *ValidationError) void {
        _ = self;
    }
};
