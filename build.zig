const std = @import("std");

pub fn build(b: *std.Build) void {
    // Set the target and optimization options
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Define the build options
    const lib = b.addStaticLibrary(.{
        .name = "graphql_parser",
        .root_source_file = b.path("src/parser.zig"),
        .target = target,
        .optimize = optimize,
        .version = .{
            .major = 0,
            .minor = 1,
            .patch = 0,
        },
    });

    // Define options for the `config` module
    const debug_mode = b.option(bool, "debug", "Enable debug mode") orelse false;

    const options = b.addOptions();
    options.addOption(bool, "debug", debug_mode);

    // Attach options for the `config` module to the library
    lib.root_module.addOptions("config.zig", options);

    // Add a test step
    const tests = b.addTest(.{
        .root_source_file = b.path("src/parser.zig"),
    });
    tests.root_module.addOptions("config.zig", options);

    const test_step = b.step("test", "Run unit tests");
    const run_tests = b.addRunArtifact(tests);
    test_step.dependOn(&run_tests.step);
}
