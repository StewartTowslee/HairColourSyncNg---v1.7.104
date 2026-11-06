cmake_minimum_required(VERSION 3.21)

# Upstream ships HairColourSyncNg.vcxproj (v143, x64, dynamic CRT).
# This file builds that same DLL. Point COMMONLIBSSE_ROOT at CommonLibSSE-NG
# v11.0.0 (94faaed0c60eddd8347767f2d4d29a97c93bde8c) or pass a pre-installed
# package via CMAKE_PREFIX_PATH.
project(HairColourSyncNg LANGUAGES CXX RC)

set(COMMONLIBSSE_ROOT "" CACHE PATH "Path to CommonLibSSE-NG v11.0.0 sources")

if(COMMONLIBSSE_ROOT)
	set(BUILD_TESTS OFF CACHE BOOL "" FORCE)
	add_subdirectory("${COMMONLIBSSE_ROOT}" "${CMAKE_BINARY_DIR}/commonlibsse" EXCLUDE_FROM_ALL)
else()
	find_package(CommonLibSSE CONFIG REQUIRED)
endif()

# version.rc is UTF-16. MSVC rc.exe accepts that. llvm-rc does not, so the
# Linux clang-cl path transcodes a copy. Resource values are unchanged.
find_program(ICONV_EXECUTABLE iconv)
if(ICONV_EXECUTABLE)
	set(VERSION_RC_UTF8 "${CMAKE_CURRENT_BINARY_DIR}/version.utf8.rc")
	add_custom_command(
		OUTPUT "${VERSION_RC_UTF8}"
		COMMAND "${ICONV_EXECUTABLE}" -f UTF-16 -t UTF-8 "${CMAKE_CURRENT_SOURCE_DIR}/version.rc" > "${VERSION_RC_UTF8}"
		DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/version.rc"
	)
	set(HAIR_VERSION_RC "${VERSION_RC_UTF8}")
else()
	set(HAIR_VERSION_RC "${CMAKE_CURRENT_SOURCE_DIR}/version.rc")
endif()

add_library(HairColourSyncNg SHARED
	dllmain.cpp
	plugin.cpp
	"${HAIR_VERSION_RC}"
)

set_target_properties(HairColourSyncNg PROPERTIES
	OUTPUT_NAME "HairColourSyncNg"
	CXX_STANDARD 23
	CXX_STANDARD_REQUIRED ON
	MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL"
)

target_include_directories(HairColourSyncNg PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")

target_compile_definitions(HairColourSyncNg PRIVATE
	SPDLOG_COMPILED_LIB
	HAIRCOLOURSYNCNG_EXPORTS
	_WINDOWS
	_USRDLL
	$<$<CONFIG:Debug>:_DEBUG>
	$<$<CONFIG:Release>:NDEBUG>
)

# The Windows SDK ships this as psapi.lib. lld-link on Linux is case-sensitive.
target_link_libraries(HairColourSyncNg PRIVATE CommonLibSSE::CommonLibSSE psapi.lib)
