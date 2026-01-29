const std = @import("std");

pub fn build(b: *std.Build) void {
    // Set the target and optimization options
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Define the build options
    const lib = b.addStaticLibrary(.{
        .name = "zig_ql",
        .root_source_file = b.path("src/zig_ql.zig"),
        .target = target,
        .optimize = optimize,
        .version = .{
            .major = 0,
            .minor = 1,
            .patch = 1,
        },
    });

    // Define options for the `build_config` module
    const debug_mode = b.option(bool, "debug", "Enable debug mode") orelse false;

    const options = b.addOptions();
    options.addOption(bool, "debug", debug_mode);

    // Attach options for the `build_config` module to the library
    lib.root_module.addOptions("build_config.zig", options);

    // Install the library
    b.installArtifact(lib);

    // Export the module so other projects can depend on it
    const module = b.addModule("zig_ql", .{
        .root_source_file = b.path("src/zig_ql.zig"),
    });
    module.addOptions("build_config.zig", options);

    // Add a test step
    const tests = b.addTest(.{
        .root_source_file = b.path("src/zig_ql.zig"),
    });
    tests.root_module.addOptions("build_config.zig", options);

    const test_step = b.step("test", "Run unit tests");
    const run_tests = b.addRunArtifact(tests);
    test_step.dependOn(&run_tests.step);
}
