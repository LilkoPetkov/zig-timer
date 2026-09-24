const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("test_raylib", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    const raylib = b.addTranslateC(.{
        .root_source_file = b.path("raylib/src/raylib.h"),
        .target = target,
        .optimize = optimize,
        .link_libc = true, // Required for most headers
    });
    raylib.addIncludePath(b.path("raylib"));

    const exe = b.addExecutable(.{
        .name = "test_raylib",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "test_raylib", .module = mod },
                .{ .name = "raylib", .module = raylib.createModule() },
            },
        }),
    });

    if (builtin.target.os.tag.isDarwin()) {
        exe.root_module.linkFramework("Cocoa", .{});
        exe.root_module.linkFramework("CoreFoundation", .{});
        exe.root_module.linkFramework("IOKit", .{});
        exe.root_module.linkFramework("CoreVideo", .{});
        exe.root_module.linkFramework("OpenGL", .{});
        exe.root_module.linkFramework("QuartzCore", .{});
    } else {
        exe.root_module.linkSystemLibrary("GL", .{});
        exe.root_module.linkSystemLibrary("X11", .{});
        exe.root_module.linkSystemLibrary("Xrandr", .{});
        exe.root_module.linkSystemLibrary("Xinerama", .{});
        exe.root_module.linkSystemLibrary("Xi", .{});
        exe.root_module.linkSystemLibrary("Xcursor", .{});

        exe.root_module.linkSystemLibrary("m", .{});
        exe.root_module.linkSystemLibrary("pthread", .{});
        exe.root_module.linkSystemLibrary("dl", .{});
        exe.root_module.linkSystemLibrary("rt", .{});
    }

    exe.root_module.addObjectFile(b.path("raylib/src/libraylib.a"));

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}
