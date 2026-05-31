cmake_minimum_required(VERSION 3.22.1)
project(mob_node)

# Paths injected by build.gradle (read from android/local.properties or env vars).
# OTP_RELEASE (arm64), OTP_RELEASE_ARM32, ERTS_VSN, MOB_DIR are set via -D flags.

# Select OTP path based on target ABI.
if(ANDROID_ABI STREQUAL "armeabi-v7a")
    set(OTP_DIR "${OTP_RELEASE_ARM32}")
else()
    set(OTP_DIR "${OTP_RELEASE}")
endif()

# Project root is 5 directories above this CMakeLists.txt
# (android/app/src/main/jni → ../../../../../). Used to locate deps/.
set(MOB_DEPS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../deps")

set(_PROJECT_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../")
if(NOT DEFINED MOB_ANDROID_PLUGIN_NATIVE_LINK_FILE OR MOB_ANDROID_PLUGIN_NATIVE_LINK_FILE STREQUAL "")
    set(MOB_ANDROID_PLUGIN_NATIVE_LINK_FILE "${_PROJECT_ROOT}/priv/generated/android_plugins/native_link.properties")
endif()

set(MOB_ANDROID_PLUGIN_GENERATED_DIR "priv/generated/android_plugins")
set(MOB_ANDROID_PLUGIN_DRIVER_TAB "priv/generated/driver_tab_android.c")

if(EXISTS "${MOB_ANDROID_PLUGIN_NATIVE_LINK_FILE}")
    file(STRINGS "${MOB_ANDROID_PLUGIN_NATIVE_LINK_FILE}" _ANDROID_PLUGIN_NATIVE_LINK_LINES)
    foreach(_native_link_line IN LISTS _ANDROID_PLUGIN_NATIVE_LINK_LINES)
        if(_native_link_line MATCHES "^[ \t]*#" OR _native_link_line MATCHES "^[ \t]*$")
            continue()
        endif()
        if(_native_link_line MATCHES "^([^=]+)=(.*)$")
            string(STRIP "${CMAKE_MATCH_1}" _native_link_key)
            string(STRIP "${CMAKE_MATCH_2}" _native_link_value)
            if(_native_link_key STREQUAL "driver_tab")
                set(MOB_ANDROID_PLUGIN_DRIVER_TAB "${_native_link_value}")
            elseif(_native_link_key STREQUAL "android_plugin_generated_dir")
                set(MOB_ANDROID_PLUGIN_GENERATED_DIR "${_native_link_value}")
            elseif(_native_link_key STREQUAL "android_plugin_objects")
                set(MOB_ANDROID_PLUGIN_OBJECTS "${_native_link_value}")
            elseif(_native_link_key STREQUAL "android_plugin_archives")
                set(MOB_ANDROID_PLUGIN_ARCHIVES "${_native_link_value}")
            elseif(_native_link_key STREQUAL "android_plugin_c_sources")
                set(MOB_ANDROID_PLUGIN_C_SOURCES "${_native_link_value}")
            endif()
        endif()
    endforeach()
elseif((NOT DEFINED MOB_ANDROID_PLUGIN_C_SOURCES OR MOB_ANDROID_PLUGIN_C_SOURCES STREQUAL "")
       AND EXISTS "${_PROJECT_ROOT}/priv/generated/android_plugins/c_sources.txt")
    file(READ "${_PROJECT_ROOT}/priv/generated/android_plugins/c_sources.txt" MOB_ANDROID_PLUGIN_C_SOURCES)
    string(STRIP "${MOB_ANDROID_PLUGIN_C_SOURCES}" MOB_ANDROID_PLUGIN_C_SOURCES)
endif()

if(NOT IS_ABSOLUTE "${MOB_ANDROID_PLUGIN_GENERATED_DIR}")
    get_filename_component(MOB_ANDROID_PLUGIN_GENERATED_DIR "${_PROJECT_ROOT}/${MOB_ANDROID_PLUGIN_GENERATED_DIR}" ABSOLUTE)
endif()
if(NOT IS_ABSOLUTE "${MOB_ANDROID_PLUGIN_DRIVER_TAB}")
    get_filename_component(MOB_ANDROID_PLUGIN_DRIVER_TAB "${_PROJECT_ROOT}/${MOB_ANDROID_PLUGIN_DRIVER_TAB}" ABSOLUTE)
endif()

string(REPLACE "," ";" MOB_ANDROID_PLUGIN_C_SOURCES "${MOB_ANDROID_PLUGIN_C_SOURCES}")
string(REPLACE "," ";" MOB_ANDROID_PLUGIN_OBJECTS "${MOB_ANDROID_PLUGIN_OBJECTS}")
string(REPLACE "," ";" MOB_ANDROID_PLUGIN_ARCHIVES "${MOB_ANDROID_PLUGIN_ARCHIVES}")

# MobDev owns the final native link for libmob_node.so. Gradle/CMake
# only package/import the prebuilt shared library from jniLibs/<abi>/.
set(ZIG_LIB_SO "${_PROJECT_ROOT}/android/app/src/main/jniLibs/${ANDROID_ABI}/libmob_node.so")

if(EXISTS "${ZIG_LIB_SO}")
    # MobDev produced the final app native library before Gradle. CMake only
    # imports it so dependent CMake targets can reference the SONAME; it does
    # not compile or link libmob_node.so.
    add_library(mob_node SHARED IMPORTED GLOBAL)
    set_target_properties(mob_node PROPERTIES
        IMPORTED_LOCATION "${ZIG_LIB_SO}"
        IMPORTED_SONAME "libmob_node.so"
    )
else()
    message(FATAL_ERROR "libmob_node.so is not present at ${ZIG_LIB_SO}. Run mix mob.deploy --native or MobDev.NativeBuild so MobDev performs the Android final native link before Gradle/CMake packaging.")
endif()

# ── exqlite / SQLite NIF ──────────────────────────────────────────────────────
# As of Phase 2 iter 11, build.zig owns sqlite3_nif's compile + link
# (mirrors libsqlite3_nif.so into jniLibs/<abi>/ alongside lib<app>.so).
# CMake only takes over when build.zig didn't run — same fallback logic
# as the main library above.
#
# mob_node does not depend on exqlite (persistence is CubDB,
# pure Elixir, no NIF). The stock mob.new CMakeLists hard-codes this
# target; gate it on the exqlite sources actually being present so the
# CMake configure step doesn't fail on the missing deps/exqlite tree.
set(ZIG_SQLITE_SO "${_PROJECT_ROOT}/android/app/src/main/jniLibs/${ANDROID_ABI}/libsqlite3_nif.so")
if(NOT EXISTS "${ZIG_SQLITE_SO}" AND EXISTS "${MOB_DEPS_DIR}/exqlite/c_src/sqlite3_nif.c")
    add_library(sqlite3_nif SHARED
        ${MOB_DEPS_DIR}/exqlite/c_src/sqlite3_nif.c
        ${MOB_DEPS_DIR}/exqlite/c_src/sqlite3.c
    )

    target_include_directories(sqlite3_nif PRIVATE
        ${MOB_DEPS_DIR}/exqlite/c_src
        ${OTP_DIR}/${ERTS_VSN}/include
    )

    target_compile_definitions(sqlite3_nif PRIVATE
        SQLITE_THREADSAFE=1
    )

    target_link_libraries(sqlite3_nif
        mob_node
        android
        log
    )
endif()  # NOT EXISTS ZIG_SQLITE_SO
