cmake_minimum_required(VERSION 3.16)
project(open_football_gdextension LANGUAGES CXX C)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Godot API version
set(GODOTCPP_API_VERSION "4.7")
set(GODOTCPP_TARGET "template_release" CACHE STRING "godot-cpp build target")

# Original GameplayFootball checkout and its current Release build.
# The first slice links the original runtime statically into the extension.
set(GPF_REPO "C:/Users/Egor/Desktop/projects/GameplayFootball-of_port" CACHE PATH "GameplayFootball checkout")
set(GPF_BUILD "${GPF_REPO}/build-x64" CACHE PATH "GameplayFootball Release build directory")
set(GPF_VCPKG "${GPF_REPO}/build-x64/vcpkg_installed/x64-windows" CACHE PATH "vcpkg installed tree used by GameplayFootball")

if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/godot-cpp/CMakeLists.txt")
    message(FATAL_ERROR "godot-cpp submodule not found. Run: git submodule update --init --recursive")
endif()
if(NOT EXISTS "${GPF_BUILD}/Release/gamelib.lib")
    message(FATAL_ERROR "GameplayFootball Release libs not found in ${GPF_BUILD}/Release")
endif()

# Match the original GameplayFootball libraries: dynamic MSVC runtime (/MD).
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL")
add_subdirectory(godot-cpp)

set(GPF_RUNTIME_SOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/src/register_types.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/match_node.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/gpf_runtime_node.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/procedural_pitch.cpp
    # Original runtime TUs not already inside the game static libs.
    ${GPF_REPO}/src/gametask.cpp
    ${GPF_REPO}/src/utils.cpp
    ${GPF_REPO}/src/dbquery.cpp
    ${GPF_REPO}/src/gamedefines.cpp
    ${GPF_REPO}/src/misc/perlin.cpp
    ${GPF_REPO}/src/misc/hungarian.c
)

add_library(open_football_gdext SHARED ${GPF_RUNTIME_SOURCES})

target_include_directories(open_football_gdext PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    ${GPF_REPO}/src
    ${GPF_VCPKG}/include
    ${GPF_VCPKG}/include/AL
)

target_compile_definitions(open_football_gdext PRIVATE
    WIN32 _WINDOWS _MBCS NOMINMAX
    BOOST_FILESYSTEM_NO_LIB BOOST_FILESYSTEM_DYN_LINK=1
    BOOST_THREAD_NO_LIB BOOST_THREAD_DYN_LINK BOOST_THREAD_USE_DLL
    BOOST_ATOMIC_NO_LIB BOOST_ATOMIC_DYN_LINK
    BOOST_CHRONO_NO_LIB BOOST_CHRONO_DYN_LINK
    BOOST_CONTAINER_NO_LIB BOOST_CONTAINER_DYN_LINK
    BOOST_DATE_TIME_NO_LIB BOOST_DATE_TIME_DYN_LINK
)

target_link_libraries(open_football_gdext PRIVATE
    godot-cpp
    ${GPF_BUILD}/Release/gamelib.lib
    ${GPF_BUILD}/Release/hidlib.lib
    ${GPF_BUILD}/Release/menulib.lib
    ${GPF_BUILD}/Release/datalib.lib
    ${GPF_BUILD}/Release/leaguelib.lib
    ${GPF_BUILD}/Release/gamecontextlib.lib
    ${GPF_BUILD}/Release/blunted2.lib
    ${GPF_VCPKG}/lib/boost_filesystem-vc143-mt-x64-1_92.lib
    ${GPF_VCPKG}/lib/boost_thread-vc143-mt-x64-1_92.lib
    ${GPF_VCPKG}/lib/boost_atomic-vc143-mt-x64-1_92.lib
    ${GPF_VCPKG}/lib/boost_chrono-vc143-mt-x64-1_92.lib
    ${GPF_VCPKG}/lib/boost_date_time-vc143-mt-x64-1_92.lib
    ${GPF_VCPKG}/lib/boost_container-vc143-mt-x64-1_92.lib
    ${GPF_VCPKG}/lib/sqlite3.lib
    ${GPF_VCPKG}/lib/SDL3_image.lib
    ${GPF_VCPKG}/lib/SDL3_ttf.lib
    ${GPF_VCPKG}/lib/SDL3.lib
    ${GPF_VCPKG}/lib/OpenAL32.lib
    opengl32.lib glu32.lib ws2_32.lib synchronization.lib dbghelp.lib
    kernel32.lib user32.lib gdi32.lib winspool.lib shell32.lib ole32.lib oleaut32.lib
    uuid.lib comdlg32.lib advapi32.lib
)

set(GDEXT_OUTPUT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../bin")
set_target_properties(open_football_gdext PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${GDEXT_OUTPUT_DIR}"
    LIBRARY_OUTPUT_DIRECTORY "${GDEXT_OUTPUT_DIR}"
    RUNTIME_OUTPUT_DIRECTORY_RELEASE "${GDEXT_OUTPUT_DIR}"
    LIBRARY_OUTPUT_DIRECTORY_RELEASE "${GDEXT_OUTPUT_DIR}"
    RUNTIME_OUTPUT_DIRECTORY_DEBUG "${GDEXT_OUTPUT_DIR}"
    LIBRARY_OUTPUT_DIRECTORY_DEBUG "${GDEXT_OUTPUT_DIR}"
)

# Original runtime dependencies (SDL/OpenAL/Boost/sqlite) must be next to the DLL.
file(GLOB GPF_RUNTIME_DLLS "${GPF_BUILD}/Release/*.dll")
add_custom_command(TARGET open_football_gdext POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different ${GPF_RUNTIME_DLLS}
            "$<TARGET_FILE_DIR:open_football_gdext>"
    COMMENT "Copying GameplayFootball runtime DLLs next to the GDExtension"
)
