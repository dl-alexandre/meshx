// Compatibility placeholder for direct invocations from this app JNI directory.
// The Android final native link implementation is owned by mob_dev and invoked
// by MobDev.NativeBuild before Gradle/CMake packaging.

const std = @import("std");

pub fn build(b: *std.Build) void {
    _ = b.option([]const u8, "abi", "Android ABI");
    _ = b.option([]const u8, "otp_dir", "Path to per-ABI Android OTP runtime");
    _ = b.option([]const u8, "erts_vsn", "ERTS version dir name");
    _ = b.option([]const u8, "mob_dir", "Path to mob library");
    _ = b.option([]const u8, "project_jni_dir", "Absolute path to app JNI dir");
    _ = b.option([]const u8, "ndk_sysroot", "Path to NDK sysroot");
    _ = b.option([]const u8, "app_name", "App native library basename");
    _ = b.option([]const u8, "project_root", "Absolute project root");
    _ = b.option([]const u8, "android_plugin_native_link_file", "Generated native plugin link metadata file");
    _ = b.option([]const u8, "driver_tab", "Generated driver table path");
    _ = b.option([]const u8, "android_plugin_c_sources", "Plugin C sources");
    _ = b.option([]const u8, "android_plugin_archives", "Plugin static archives");
    _ = b.option([]const u8, "android_plugin_objects", "Generated Android plugin support objects");
    _ = b.option([]const u8, "android_plugin_c_sources_file", "Deprecated plugin C source list");
    _ = b.option([]const u8, "android_plugin_generated_dir", "Generated Android plugin support C dir");
    _ = b.option([]const u8, "exqlite_src", "Optional exqlite source dir");
    _ = b.option([]const u8, "project_c_nifs", "Project C NIF names");
    _ = b.option([]const u8, "project_rust_libs", "Project native static libraries");
    _ = b.option([]const u8, "enif_keepalive", "Optional enif keepalive C source");

    const native_lib_step = b.step("native-lib", "Android final native link is owned by mob_dev");
    b.default_step = native_lib_step;

    const fail = b.addSystemCommand(&.{
        "sh",
        "-c",
        "echo 'Android final native link is owned by mob_dev. Run mix mob.deploy --native or invoke deps/mob_dev/priv/android_native_build/build.zig.' >&2; exit 1",
    });
    native_lib_step.dependOn(&fail.step);
}
