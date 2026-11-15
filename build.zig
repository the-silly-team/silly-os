const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .x86,
        .os_tag = .freestanding,
        .abi = .none,
    });

    const optimize = b.standardOptimizeOption(.{});

    const kernel = b.addExecutable(.{
        .name = "sillyos",
        .root_source_file = b.path("src/kernel.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Use our linker script
    kernel.setLinkerScriptPath(b.path("boot/linker.ld"));

    b.installArtifact(kernel);

    // Build ISO step
    const iso_step = b.step("iso", "Build bootable ISO");
    const iso_cmd = b.addSystemCommand(&.{
        "grub-mkrescue",
        "-o",
        "sillyos.iso",
        "iso/",
    });
    iso_cmd.step.dependOn(b.getInstallStep());
    iso_step.dependOn(&iso_cmd.step);
}
