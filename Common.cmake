# Common.cmake
#
# Purpose: Centralizes CMake logic for projects with a main executable and dependencies as interface libraries.
# Hosted in https://github.com/LIONant-depot/xcmake_tools.git to avoid duplication.
# Functions: Fetch dependencies, define components, process components.
# Sets Visual Studio startup project to ${TARGET_PROJECT}.
#
# Usage:
# - Host in xcmake_tools Git repository, main branch.
# - In Project/CMakeLists.txt:
#     include(FetchContent)
#     FetchContent_Declare(
#       xcmake_tools
#       GIT_REPOSITORY https://github.com/LIONant-depot/xcmake_tools.git
#       GIT_TAG main
#       GIT_SHALLOW TRUE
#       SOURCE_DIR "${CMAKE_BINARY_DIR}/_deps/xcmake_tools"
#     )
#     FetchContent_MakeAvailable(xcmake_tools)
#     include(${CMAKE_BINARY_DIR}/_deps/xcmake_tools/Common.cmake)
# - In Build/Dependency/CMakeLists.txt: include(${CMAKE_BINARY_DIR}/_deps/xcmake_tools/Common.cmake)
# - Call FetchAndPopulate(<repo> [<tag>]) for dependencies.
# - Call DefineInterfaceComponent(<comp_name> <group> <file_list>) for components.
# - Call ProcessComponents() to link components (defaults to ${TARGET_PROJECT}).
# - Override startup project with set_property(DIRECTORY ... VS_STARTUP_PROJECT <target>) if needed.
# - For breaking changes, rename to Common2.cmake and update include paths.
#
# Notes:
# - FetchAndPopulate requires a full repository URL; default tag is "main".
# - DefineInterfaceComponent requires GROUP; appends /<comp_name> to form IDE group; raises FATAL_ERROR if omitted.
# - ProcessComponents defaults to ${TARGET_PROJECT}; raises FATAL_ERROR if undefined.
# - Sets VS_STARTUP_PROJECT for MSVC; requires ${TARGET_PROJECT}.
# - Uses global properties for component metadata.
# - Checks for CMakeLists.txt to avoid add_subdirectory errors.
# - Only sets properties/files for new targets.

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
  add_definitions(-DUNICODE -D_UNICODE)
  
  # Set Visual Studio startup project to ${TARGET_PROJECT}
  if(NOT TARGET_PROJECT)
    message(FATAL_ERROR "TARGET_PROJECT must be defined before including Common.cmake to set VS_STARTUP_PROJECT. "
                        "Example: set(TARGET_PROJECT \"my_project\")")
  endif()
  set_property(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR} PROPERTY VS_STARTUP_PROJECT ${TARGET_PROJECT})
endif()

set(CMAKE_CXX_STANDARD 20)              # Require C++20
set(CMAKE_CXX_STANDARD_REQUIRED ON)     # Enforce C++ standard
set(CMAKE_SUPPRESS_REGENERATION true)   # Skip ZERO_CHECK project in Visual Studio
set(CMAKE_SKIP_INSTALL_RULES true)      # Disable installation rules
set(CMAKE_CONFIGURATION_TYPES "Debug;Release" CACHE STRING "Limit to Debug and Release builds" FORCE)

#------------------------------------------------------------------------------
# Function: FetchAndPopulate
# Purpose: Fetches a dependency using FetchContent, checks for CMakeLists.txt, adds subdirectory.
# Parameters:
# - REPO: Full repository URL (required).
# - TAG (optional): Git tag (defaults to "main").
# Returns: Sets ${DEP_NAME}_POPULATED to TRUE/FALSE.
# Usage:
#   FetchAndPopulate("https://github.com/LIONant-depot/xtextfile.git")
#   FetchAndPopulate("https://git.example.com/xcmdline.git" "release")
#   if(xcmdline_POPULATED)
#     message(STATUS "xcmdline was populated")
#   endif()
#------------------------------------------------------------------------------
function(FetchAndPopulate REPO TAG)
  set(options)
  set(oneValueArgs)
  set(multiValueArgs)
  cmake_parse_arguments(FP "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
  
  get_filename_component(DEP_BASENAME "${REPO}" NAME)
  string(REGEX REPLACE "\\.git$" "" DEP_NAME "${DEP_BASENAME}")
  
  if(NOT DEP_NAME)
    message(FATAL_ERROR "Could not extract dependency name from REPO: ${REPO}")
  endif()
  
  # Use provided TAG or default to "main"
  if(NOT TAG)
    set(FP_TAG "main")
  else()
    set(FP_TAG "${TAG}")
  endif()
  
  FetchContent_Declare(
    ${DEP_NAME}
    GIT_REPOSITORY ${REPO}
    GIT_TAG ${FP_TAG}
    GIT_SHALLOW TRUE  # Shallow clone for efficiency
    SOURCE_DIR "${CMAKE_SOURCE_DIR}/dependencies/${DEP_NAME}"
  )

  FetchContent_GetProperties(${DEP_NAME})
  if(NOT ${DEP_NAME}_POPULATED)
    message(STATUS "Populating ${DEP_NAME} from ${REPO} with tag ${FP_TAG}...")
    FetchContent_Populate(${DEP_NAME})

    set(SUBDIR "${CMAKE_SOURCE_DIR}/dependencies/${DEP_NAME}/build/dependency")
    if(EXISTS "${SUBDIR}/CMakeLists.txt")
      add_subdirectory("${SUBDIR}" "${CMAKE_CURRENT_BINARY_DIR}/${DEP_NAME}")
    endif()

    set(${DEP_NAME}_POPULATED TRUE PARENT_SCOPE)

  else()

    set(${DEP_NAME}_POPULATED FALSE PARENT_SCOPE)
  endif()
endfunction()

#------------------------------------------------------------------------------
# Function: DefineInterfaceComponent
# Purpose: Defines an interface library, sets include directories and properties only if new.
# Parameters:
# - COMP_NAME: Component name (e.g., xresource_pipeline_v2).
# - GROUP: Parent folder for IDE group (required, e.g., "dependencies/xcore"); /<comp_name> is appended.
# - ARGN: Source files, relative to component root.
# Returns: Sets ${COMP_NAME}_CREATED to TRUE/FALSE.
# Usage:
#   DefineInterfaceComponent(xresource_pipeline_v2 "dependencies/xcore" "source/xresource_pipeline.h" ...)
#   if(xresource_pipeline_v2_CREATED)
#     message(STATUS "xresource_pipeline_v2 was created")
#   endif()
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

    # Append /COMP_NAME to GROUP for IDE organization
    set(GROUP_NAME "${GROUP}/${COMP_NAME}")

    # Set properties and files only for newly created targets
    set_property(GLOBAL PROPERTY ${COMP_NAME}_GROUP "${GROUP_NAME}")        # Store group for IDE organization
    set_property(GLOBAL PROPERTY ${COMP_NAME}_INCLUDES "${ROOT}")           # Store include paths
    set_property(GLOBAL APPEND PROPERTY COMPONENT_REGISTRY "${COMP_NAME}")  # Register component
    set(FILES ${DIC_UNPARSED_ARGUMENTS})

    # Prepend ROOT to file paths
    set(FILES "")
    foreach(FILE ${DIC_UNPARSED_ARGUMENTS})
      list(APPEND FILES "${ROOT}/${FILE}")
    endforeach()

    set_property(GLOBAL APPEND PROPERTY ${COMP_NAME}_FILES ${FILES})
  endif()
  
  # Return whether the library was created
  set(${COMP_NAME}_CREATED ${CREATED} PARENT_SCOPE)
endfunction()

#------------------------------------------------------------------------------
# Function: ProcessComponents
# Purpose: Links components to the main executable, adds sources, includes, linker paths.
# Parameters:
# - TARGET (optional): Target to link components to (defaults to ${TARGET_PROJECT}).
# Usage:
#   ProcessComponents()               # Uses ${TARGET_PROJECT}
#   ProcessComponents(custom_target)  # Explicit target
#------------------------------------------------------------------------------
function(ProcessComponents)
  set(options)
  set(oneValueArgs TARGET)
  set(multiValueArgs)
  cmake_parse_arguments(PC "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
  
  if(NOT PC_TARGET)
    if(NOT TARGET_PROJECT)
      message(FATAL_ERROR "TARGET_PROJECT must be defined for ProcessComponents when no TARGET is provided. "
                          "Example: set(TARGET_PROJECT \"my_project\")")
    endif()
    set(PC_TARGET "${TARGET_PROJECT}")
  endif()
  
  get_property(REG GLOBAL PROPERTY COMPONENT_REGISTRY)
  message(STATUS "Processing: ${REG}")
  foreach(COMP ${REG})
    get_property(FILES GLOBAL PROPERTY ${COMP}_FILES)
    if(FILES)
      target_sources(${PC_TARGET} PRIVATE ${FILES})
      get_property(GROUP GLOBAL PROPERTY ${COMP}_GROUP)
      if(GROUP)
        source_group("${GROUP}" FILES ${FILES})
      endif()
    endif()
    get_property(INCS GLOBAL PROPERTY ${COMP}_INCLUDES)
    if(INCS)
      target_include_directories(${PC_TARGET} PRIVATE ${INCS})
    endif()
    get_property(LINK_PATHS GLOBAL PROPERTY ${COMP}_LINKER_PATHS)
    if(LINK_PATHS)
      target_link_directories(${PC_TARGET} PRIVATE ${LINK_PATHS})
    endif()
  endforeach()
endfunction()

# Function: AppendComponentIncludes
# Purpose: Appends additional include directories to a component's ${COMP_NAME}_INCLUDES property.
# Parameters:
# - COMP_NAME: Component name (e.g., xcompression).
# - ARGN: List of include directories to append.
# Usage:
#   AppendComponentIncludes(xcompression "${CMAKE_SOURCE_DIR}/dependencies/zstd")
function(AppendComponentIncludes COMP_NAME)
  get_property(CURRENT_INCLUDES GLOBAL PROPERTY ${COMP_NAME}_INCLUDES)
  list(APPEND CURRENT_INCLUDES ${ARGN})
  set_property(GLOBAL PROPERTY ${COMP_NAME}_INCLUDES "${CURRENT_INCLUDES}")
endfunction()