cmake_minimum_required(VERSION 3.19)

# Enhanced build configuration with better error handling and optimization
if(NOT DEFINED VERSION)
    execute_process(COMMAND git describe --tags --abbrev=0
        WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
        OUTPUT_VARIABLE VERSION
        OUTPUT_STRIP_TRAILING_WHITESPACE
        RESULT_VARIABLE GIT_RESULT
    )

    if("${VERSION}" STREQUAL "" OR GIT_RESULT)
        message(FATAL_ERROR "VERSION is not set and failed to get from git (result: ${GIT_RESULT})")
    endif()
endif()

if(NOT DEFINED GIT_REVISION)
    execute_process(COMMAND git rev-parse HEAD
        WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
        OUTPUT_VARIABLE GIT_REVISION
        OUTPUT_STRIP_TRAILING_WHITESPACE
        RESULT_VARIABLE GIT_REV_RESULT
    )

    if("${GIT_REVISION}" STREQUAL "" OR GIT_REV_RESULT)
        message(FATAL_ERROR "GIT_REVISION is not set and failed to get from git (result: ${GIT_REV_RESULT})")
    endif()
endif()

string(REGEX REPLACE "^v" "" VERSION "${VERSION}")

project(caelestia-shell VERSION ${VERSION} LANGUAGES CXX)

# Modern C++ configuration with enhanced compiler flags
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")

# Build type configuration
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE "Release" CACHE STRING "Build type" FORCE)
endif()

# Enhanced compiler warnings and optimizations
set(COMPILER_FLAGS
    -Wall -Wextra -Wpedantic -Wshadow -Wconversion
    -Wold-style-cast -Wnull-dereference -Wdouble-promotion
    -Wformat=2 -Wfloat-equal -Woverloaded-virtual
    -Wsign-conversion -Wredundant-decls -Wswitch
    -Wunreachable-code -Wnon-virtual-dtor
    $<$<CONFIG:Debug>:-g -O0 -DDEBUG>
    $<$<CONFIG:Release>:-O3 -DNDEBUG -march=native>
    $<$<CONFIG:RelWithDebInfo>:-O2 -g -DNDEBUG>
)

# Platform-specific optimizations
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    list(APPEND COMPILER_FLAGS -pthread)
    if(CMAKE_CXX_COMPILER_ID MATCHES "GNU")
        list(APPEND COMPILER_FLAGS -fdiagnostics-color=always)
    endif()
endif()

add_compile_options(${COMPILER_FLAGS})

# Clang-specific optimizations
if(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    add_compile_options(-Wunused-lambda-capture)
    if(CMAKE_BUILD_TYPE STREQUAL "Release")
        add_compile_options(-flto)
        add_link_options(-flto)
    endif()
endif()

# GCC-specific optimizations
if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
    if(CMAKE_BUILD_TYPE STREQUAL "Release")
        add_compile_options(-flto -fno-fat-lto-objects)
        add_link_options(-flto -fno-fat-lto-objects)
    endif()
endif()

# Enhanced dependency checking
find_package(PkgConfig QUIET)
if(PkgConfig_FOUND)
    # Check for required system dependencies
    pkg_check_modules(QT6 REQUIRED IMPORTED_TARGET Qt6)
    pkg_check_modules(PIPEWIRE REQUIRED IMPORTED_TARGET libpipewire-0.3)
endif()

# Configuration options with validation
set(DISTRIBUTOR "Unset" CACHE STRING "Distributor")
set(ENABLE_MODULES "extras;plugin;shell" CACHE STRING "Modules to build/install")
set(INSTALL_LIBDIR "usr/lib/caelestia" CACHE STRING "Library install dir")
set(INSTALL_QMLDIR "usr/lib/qt6/qml" CACHE STRING "QML install dir")
set(INSTALL_QSCONFDIR "etc/xdg/quickshell/caelestia" CACHE STRING "Quickshell config install dir")

# Validate modules
set(VALID_MODULES extras plugin shell)
foreach(module ${ENABLE_MODULES})
    if(NOT module IN_LIST VALID_MODULES)
        message(FATAL_ERROR "Invalid module '${module}'. Valid modules: ${VALID_MODULES}")
    endif()
endforeach()

# Installation path validation
foreach(var INSTALL_LIBDIR INSTALL_QMLDIR INSTALL_QSCONFDIR)
    if(NOT DEFINED ${var} OR ${var} STREQUAL "")
        message(FATAL_ERROR "${var} must be set to a valid path")
    endif()
endforeach()

# Module building with dependency tracking
if("extras" IN_LIST ENABLE_MODULES)
    message(STATUS "Building extras module")
    add_subdirectory(extras)
endif()

if("plugin" IN_LIST ENABLE_MODULES)
    message(STATUS "Building plugin module")
    add_subdirectory(plugin)
endif()

if("shell" IN_LIST ENABLE_MODULES)
    message(STATUS "Building shell module")
    
    # Install shell components with proper permissions
    foreach(dir assets components config modules services utils)
        install(DIRECTORY ${dir} 
            DESTINATION "${INSTALL_QSCONFDIR}"
            FILE_PERMISSIONS OWNER_READ OWNER_WRITE GROUP_READ WORLD_READ
            DIRECTORY_PERMISSIONS OWNER_READ OWNER_WRITE EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE
        )
    endforeach()
    
    install(FILES shell.qml LICENSE 
        DESTINATION "${INSTALL_QSCONFDIR}"
        PERMISSIONS OWNER_READ OWNER_WRITE GROUP_READ WORLD_READ
    )
endif()

# Build information
message(STATUS "Build configuration:")
message(STATUS "  Version: ${VERSION}")
message(STATUS "  Git revision: ${GIT_REVISION}")
message(STATUS "  Build type: ${CMAKE_BUILD_TYPE}")
message(STATUS "  Compiler: ${CMAKE_CXX_COMPILER_ID} ${CMAKE_CXX_COMPILER_VERSION}")
message(STATUS "  Modules: ${ENABLE_MODULES}")
message(STATUS "  Install prefix: ${CMAKE_INSTALL_PREFIX}")

# Create package configuration
include(CMakePackageConfigHelpers)
configure_package_config_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/cmake/caelestia-shell-config.cmake.in"
    "${CMAKE_CURRENT_BINARY_DIR}/caelestia-shell-config.cmake"
    INSTALL_DESTINATION "${INSTALL_LIBDIR}/cmake/caelestia-shell"
)

write_basic_package_version_file(
    "${CMAKE_CURRENT_BINARY_DIR}/caelestia-shell-config-version.cmake"
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY SameMajorVersion
)

install(FILES
    "${CMAKE_CURRENT_BINARY_DIR}/caelestia-shell-config.cmake"
    "${CMAKE_CURRENT_BINARY_DIR}/caelestia-shell-config-version.cmake"
    DESTINATION "${INSTALL_LIBDIR}/cmake/caelestia-shell"
)
