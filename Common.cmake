# Common.cmake
#
# Purpose:
# This file centralizes shared CMake logic for projects with a main executable (e.g., unit tests)
# and dependencies managed as interface libraries. It provides reusable functions to:
# - Fetch and populate external dependencies using FetchContent.
# - Define interface libraries for components with source files and includes.
# - Process components to link them to the main executable.
# It is designed to reduce boilerplate, prevent errors, and improve maintainability.
#
# Usage:
# - Place this file in Build/Dependency/.
# - In Project/CMakeLists.txt (main), include with: include(${CMAKE_SOURCE_DIR}/Build/Dependency/Common.cmake)
# - In Build/Dependency/CMakeLists.txt (sub), include with: include(Common.cmake)
# - Call FetchAndPopulate(<dep_name>) to fetch dependencies.
# - Call DefineInterfaceComponent(<comp_name> <file_list>) to define components.
# - Call ProcessComponents(<target>) in the main CMake to link components to the executable.
#
# Notes:
# - Assumes dependencies are hosted at https://github.com/LIONant-depot/<dep_name>.git with tag "main".
# - Uses global properties to track component metadata (files, includes, groups).
# - Functions return values (TRUE/FALSE) for conditional logic (e.g., if(<dep>_POPULATED)).
# - Checks for CMakeLists.txt existence to avoid errors in add_subdirectory.

cmake_minimum_required(VERSION 3.10)
include(FetchContent)

#
# Set common policies and compiler settings for consistent builds
#
if(POLICY CMP0169)
  # Set CMP0169 to OLD to allow FetchContent_Populate without auto-executing root CMakeLists
  cmake_policy(SET CMP0169 OLD)
endif()

if(MSVC)
  # Enable Unicode support and UTF-8 encoding for MSVC builds
  add_definitions(-DUNICODE -D_UNICODE)
  add_compile_options(/utf-8)
endif()

set(CMAKE_CXX_STANDARD 20)              # Require C++20
set(CMAKE_CXX_STANDARD_REQUIRED ON)     # Enforce C++ standard
set(CMAKE_SUPPRESS_REGENERATION true)   # Skip ZERO_CHECK project in Visual Studio
set(CMAKE_SKIP_INSTALL_RULES true)      # Disable installation rules
set(CMAKE_CONFIGURATION_TYPES "Debug;Release" CACHE STRING "Limit to Debug and Release builds" FORCE)

#------------------------------------------------------------------------------
# Function: FetchAndPopulate
# Purpose: Fetches and populates an external dependency using FetchContent, checking for CMakeLists.txt
# before adding it as a subdirectory. Returns TRUE if the dependency is freshly populated, FALSE if already populated.
# Parameters:
# - DEP_NAME: Name of the dependency (e.g., xtextfile, xcmdline).
# Returns: Sets ${DEP_NAME}_POPULATED to TRUE/FALSE in parent scope.
# Usage:
#   FetchAndPopulate(xtextfile)
#   if(xtextfile_POPULATED)
#     message(STATUS "xtextfile was populated")
#   endif()
#------------------------------------------------------------------------------
function(FetchAndPopulate DEP_NAME)

  set(REPO "https://github.com/LIONant-depot/${DEP_NAME}.git")  # Repository URL
  set(TAG "main")                                               # Git tag to fetch

  FetchContent_Declare(
    ${DEP_NAME}
    GIT_REPOSITORY ${REPO}
    GIT_TAG ${TAG}
    SOURCE_DIR "${CMAKE_SOURCE_DIR}/dependencies/${DEP_NAME}"   # Store in dependencies/<dep_name>
  )

  FetchContent_GetProperties(${DEP_NAME})
  if(NOT ${DEP_NAME}_POPULATED)
    message(STATUS "Populating ${DEP_NAME}...")
    FetchContent_Populate(${DEP_NAME})

    # Check for CMakeLists.txt to avoid errors if subdirectory is missing it
    set(SUBDIR "${CMAKE_SOURCE_DIR}/dependencies/${DEP_NAME}/build/dependency")
    if(EXISTS "${SUBDIR}/CMakeLists.txt")
      add_subdirectory("${SUBDIR}" "${CMAKE_CURRENT_BINARY_DIR}/${DEP_NAME}")
    endif()

    # Return TRUE to indicate the dependency was populated
    set(${DEP_NAME}_POPULATED TRUE PARENT_SCOPE)

  else()
  
    # Return FALSE to indicate the dependency was already populated
    set(${DEP_NAME}_POPULATED FALSE PARENT_SCOPE)
  endif()
endfunction()

#------------------------------------------------------------------------------
# Function: DefineInterfaceComponent
# Purpose: Defines an interface library for a component, setting up include directories and global
# properties for files and groups only if the target is newly created. Returns TRUE if the library
# is newly created, FALSE if it already exists (to respect external configurations).
# Parameters:
# - COMP_NAME: Name of the component (e.g., xresource_pipeline_v2).
# - GROUP: IDE group name for organizing files (required, e.g., "external dependencies/xresource_pipeline").
# - ARGN: List of source files for the component.
# Returns: Sets ${COMP_NAME}_CREATED to TRUE/FALSE in parent scope.
# Usage:
#   DefineInterfaceComponent(xresource_pipeline_v2 "dependencies/xresource_pipeline" "source/xresource_pipeline.h" ...)
#   if(xresource_pipeline_v2_CREATED)
#     message(STATUS "xresource_pipeline_v2 was created")
#   endif()
# Error Handling:
# - Raises a FATAL_ERROR if GROUP is not provided, with guidance to specify a meaningful IDE group name.
#------------------------------------------------------------------------------
function(DefineInterfaceComponent COMP_NAME GROUP)
  set(options)
  set(oneValueArgs)
  set(multiValueArgs)
  cmake_parse_arguments(DIC "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
  
  # Ensure GROUP is provided
  if(NOT GROUP)
    message(FATAL_ERROR "GROUP parameter is required for DefineInterfaceComponent(${COMP_NAME}). "
                        "Specify a meaningful IDE group name (e.g., '${COMP_NAME}' or a custom name like 'my_group'). "
                        "This organizes source files in the IDE (e.g., Visual Studio). Example: "
                        "DefineInterfaceComponent(${COMP_NAME} \"${COMP_NAME}\" <file_list>)")
  endif()
  
  set(CREATED FALSE)
  if(NOT TARGET ${COMP_NAME})
    set(CREATED TRUE)
    add_library(${COMP_NAME} INTERFACE)  # Create interface library

    # Set root path: "." for unit tests, "dependencies/<comp_name>" otherwise
    if("${TARGET_PROJECT}" STREQUAL "${COMP_NAME}_unit_test")
      set(ROOT ".")
    else()
      set(ROOT "dependencies/${COMP_NAME}")
      target_include_directories(${COMP_NAME} INTERFACE "${ROOT}")
    endif()

    # Set properties and files only for newly created targets
    set_property(GLOBAL PROPERTY ${COMP_NAME}_GROUP "${GROUP}")  # Store group for IDE organization
    set_property(GLOBAL PROPERTY ${COMP_NAME}_INCLUDES "${ROOT}")  # Store include paths
    set_property(GLOBAL APPEND PROPERTY COMPONENT_REGISTRY "${COMP_NAME}")  # Register component
    set(FILES ${DIC_UNPARSED_ARGUMENTS})
    set_property(GLOBAL APPEND PROPERTY ${COMP_NAME}_FILES ${FILES})  # Store files
  endif()
  
  # Return whether the library was created
  set(${COMP_NAME}_CREATED ${CREATED} PARENT_SCOPE)
endfunction()

#------------------------------------------------------------------------------
# Function: ProcessComponents
# Purpose: Links registered components to the main executable by adding their sources, includes,
# and linker paths. Organizes files in IDE groups for clarity.
# Parameters:
# - TARGET: The main executable target (e.g., xproperty_unit_test).
# Usage:
#   ProcessComponents(${TARGET_PROJECT})
#------------------------------------------------------------------------------
function(ProcessComponents TARGET)

  get_property(REG GLOBAL PROPERTY COMPONENT_REGISTRY)
  message(STATUS "Processing: ${REG}")

  foreach(COMP ${REG})
    # Add source files to the target
    get_property(FILES GLOBAL PROPERTY ${COMP}_FILES)
    if(FILES)
      target_sources(${TARGET} PRIVATE ${FILES})
      # Organize files in IDE using group property
      get_property(GROUP GLOBAL PROPERTY ${COMP}_GROUP)
      if(GROUP)
        source_group("${GROUP}" FILES ${FILES})
      endif()
    endif()

    # Add include directories to the target
    get_property(INCS GLOBAL PROPERTY ${COMP}_INCLUDES)
    if(INCS)
      target_include_directories(${TARGET} PRIVATE ${INCS})
    endif()

    # Add linker paths if specified
    get_property(LINK_PATHS GLOBAL PROPERTY ${COMP}_LINKER_PATHS)
    if(LINK_PATHS)
      target_link_directories(${TARGET} PRIVATE ${LINK_PATHS})
    endif()

  endforeach()
endfunction()