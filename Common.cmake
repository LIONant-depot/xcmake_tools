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
  
  # Enable multicore compilation for Visual Studio
  add_compile_options(/MP)

  # Set Visual Studio startup project to ${TARGET_PROJECT}
  if(NOT TARGET_PROJECT)
    message(FATAL_ERROR "TARGET_PROJECT must be defined before including Common.cmake to set VS_STARTUP_PROJECT. "
                        "Example: set(TARGET_PROJECT \"my_project\")")
  endif()

  # Enable the defal project to be the default selected option
  set_property(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR} PROPERTY VS_STARTUP_PROJECT ${TARGET_PROJECT})
endif()

set(CMAKE_CXX_STANDARD 20)              # Require C++20
set(CMAKE_CXX_STANDARD_REQUIRED ON)     # Enforce C++ standard
set(CMAKE_SUPPRESS_REGENERATION true)   # Skip ZERO_CHECK project in Visual Studio
set(CMAKE_SKIP_INSTALL_RULES true)      # Disable installation rules
set(CMAKE_CONFIGURATION_TYPES "Debug;Release" CACHE STRING "Limit to Debug and Release builds" FORCE)

# Function: FetchAndPopulate
# Purpose: Fetches a dependency using FetchContent, checks for CMakeLists.txt, adds subdirectory.
# Parameters:
# - REPO: Full repository URL (required).
# - TAG (optional): Git tag (defaults to "main").
# Returns: Sets ${DEP_NAME}_POPULATED to TRUE/FALSE.
# Usage:
#   FetchAndPopulate("https://github.com/LIONant-depot/xtextfile.git")
#   FetchAndPopulate("https://git.example.com/xcmdline.git" "release")
function(FetchAndPopulate REPO)
  find_package(Git REQUIRED)
  
  # Parse arguments: TAG is optional positional argument
  if("${ARGC}" GREATER 1)
    set(FP_TAG "${ARGV1}")
  else()
    set(FP_TAG "main")
  endif()
  
  get_filename_component(DEP_BASENAME "${REPO}" NAME)
  string(REGEX REPLACE "\\.git$" "" DEP_NAME "${DEP_BASENAME}")
  
  if(NOT DEP_NAME)
    message(FATAL_ERROR "Could not extract dependency name from REPO: ${REPO}")
  endif()
  
  set(DEP_SOURCE_DIR "${CMAKE_SOURCE_DIR}/dependencies/${DEP_NAME}")
  
  # Check if the repository already exists
  set(SHOULD_POPULATE TRUE)
  Message(STATUS "Checking if ${DEP_SOURCE_DIR} Exists or not!")
  if(EXISTS "${DEP_SOURCE_DIR}/.git")
     Message(STATUS "This is in fact a directory ${DEP_SOURCE_DIR}")
  endif()


# Check if the repository already exists
set(SHOULD_POPULATE TRUE)
set(DEP_SOURCE_DIR "${CMAKE_SOURCE_DIR}/dependencies/${DEP_NAME}")







set(DEP_SOURCE_DIR "${CMAKE_SOURCE_DIR}/dependencies/${DEP_NAME}")

# Check if the repository already exists
set(SHOULD_POPULATE TRUE)
message(STATUS "Checking if ${DEP_SOURCE_DIR} Exists or not!")
file(TO_NATIVE_PATH "${DEP_SOURCE_DIR}/.git" GIT_DIR_NATIVE)
message(STATUS "Git dir path: ${GIT_DIR_NATIVE}")
execute_process(
  COMMAND powershell -Command "Test-Path -PathType Container -Path \"${GIT_DIR_NATIVE}\""
  RESULT_VARIABLE ps_result
  OUTPUT_VARIABLE ps_out
  ERROR_VARIABLE ps_err
)
string(STRIP "${ps_out}" ps_out)
message(STATUS "PowerShell result: ${ps_result}, Out: ${ps_out}, Err: ${ps_err}")
if(ps_result EQUAL 0 AND "${ps_out}" STREQUAL "True")
  message(STATUS "This is in fact a directory and Git repo ${DEP_SOURCE_DIR}")
  set(SHOULD_POPULATE FALSE)
else()
  message(STATUS "Git directory not detected")
endif()







message(STATUS "Hello!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")

  if(EXISTS "${DEP_SOURCE_DIR_WIN}\.git")
    Message(STATUS "Skipping fetch for ${DEP_NAME}: Directory found!")
    set(SHOULD_POPULATE FALSE)

   ## if(EXISTS "${DEP_SOURCE_DIR}/.git")
   ## message(STATUS "Found existing ${DEP_NAME} at ${DEP_SOURCE_DIR}. Checking tag...")
   ## execute_process(
   ##   COMMAND ${GIT_EXECUTABLE} rev-parse --abbrev-ref HEAD
   ##   WORKING_DIRECTORY "${DEP_SOURCE_DIR}"
   ##   RESULT_VARIABLE GIT_RESULT
   ##   OUTPUT_VARIABLE CURRENT_BRANCH
   ##   OUTPUT_STRIP_TRAILING_WHITESPACE
   ##   ERROR_QUIET
   ## )
   ## if(GIT_RESULT EQUAL 0)
   ##   if("${CURRENT_BRANCH}" STREQUAL "${FP_TAG}" OR "${FP_TAG}" STREQUAL "master" OR "${FP_TAG}" STREQUAL "main")
   ##     set(SHOULD_POPULATE FALSE)
   ##     message(STATUS "Skipping fetch for ${DEP_NAME}: already at ${FP_TAG} or compatible branch")
   ##   else()
   ##     execute_process(
   ##       COMMAND ${GIT_EXECUTABLE} describe --tags --exact-match
   ##       WORKING_DIRECTORY "${DEP_SOURCE_DIR}"
   ##       RESULT_VARIABLE TAG_RESULT
   ##       OUTPUT_VARIABLE CURRENT_TAG
   ##       OUTPUT_STRIP_TRAILING_WHITESPACE
   ##       ERROR_QUIET
   ##     )
   ##     if(TAG_RESULT EQUAL 0 AND "${CURRENT_TAG}" STREQUAL "${FP_TAG}")
   ##       set(SHOULD_POPULATE FALSE)
   ##       message(STATUS "Skipping fetch for ${DEP_NAME}: tag ${FP_TAG} matches")
   ##     endif()
   ##   endif()
   ## endif()
  endif()
  
  FetchContent_Declare(
    ${DEP_NAME}
    GIT_REPOSITORY ${REPO}
    GIT_TAG ${FP_TAG}
    GIT_SHALLOW TRUE
    GIT_SUBMODULES_RECURSE TRUE
    GIT_CLONE_FLAGS "--jobs=8"
    SOURCE_DIR "${DEP_SOURCE_DIR}"
  ) 
  FetchContent_GetProperties(${DEP_NAME})
  if(NOT ${DEP_NAME}_POPULATED AND SHOULD_POPULATE)
    message(STATUS "Populating ${DEP_NAME} from ${REPO} with tag ${FP_TAG}...")
    FetchContent_Populate(${DEP_NAME})
    set(SUBDIR "${CMAKE_SOURCE_DIR}/dependencies/${DEP_NAME}/build/dependency")
    if(EXISTS "${SUBDIR}/CMakeLists.txt")
      add_subdirectory("${SUBDIR}" "${CMAKE_CURRENT_BINARY_DIR}/${DEP_NAME}")
    else()
      message(WARNING "No CMakeLists.txt in ${SUBDIR}. Skipping add_subdirectory.")
    endif()
    set(${DEP_NAME}_POPULATED TRUE PARENT_SCOPE)
  else()
    if(EXISTS "${DEP_SOURCE_DIR}")
      set(SUBDIR "${CMAKE_SOURCE_DIR}/dependencies/${DEP_NAME}/build/dependency")
      if(EXISTS "${SUBDIR}/CMakeLists.txt")
        add_subdirectory("${SUBDIR}" "${CMAKE_CURRENT_BINARY_DIR}/${DEP_NAME}")
      endif()
    endif()
    set(${DEP_NAME}_POPULATED FALSE PARENT_SCOPE)
  endif()
endfunction()

#------------------------------------------------------------------------------
# Function: DefineInterfaceComponent
# Purpose: Defines an interface library, sets include directories and properties only if new.
# Parameters:
# - COMP_NAME: Component name (e.g., xresource_pipeline_v2).
# - GROUP: Parent folder for IDE group (required, e.g., "dependencies/xcore"); /<comp_name> is appended.
# - ARGN: Source files, relative to component root, with optional **subgroup markers to set IDE subgroups.
# Returns: Sets ${COMP_NAME}_CREATED to TRUE/FALSE.
# Usage:
#   DefineInterfaceComponent(xtexture_compiler "dependencies/xcore"
#     "source/Compiler/main.cpp"
#     "**Texture_Compiler/Source Files"
#     "source/Compiler/xtexture_compiler.cpp"
#     "**Texture_Compiler/Header Files"
#     "source/xtexture_rsc_descriptor.h"
#   )
#------------------------------------------------------------------------------
function(DefineInterfaceComponent COMP_NAME GROUP)
  set(options)
  set(oneValueArgs)
  set(multiValueArgs)
  cmake_parse_arguments(DIC "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
  
  if(NOT GROUP)
    message(FATAL_ERROR "GROUP parameter required for DefineInterfaceComponent(${COMP_NAME}). "
                        "Specify a parent folder for the IDE group (e.g., 'dependencies/xcore'). "
                        "/${COMP_NAME} will be appended (e.g., 'dependencies/xcore/${COMP_NAME}'). "
                        "Example: DefineInterfaceComponent(${COMP_NAME} \"dependencies/xcore\" <file_list>)")
  endif()
  
  if("${COMP_NAME}" STREQUAL "${TARGET_PROJECT}")
     # This is not allowed as it will cause issues with include paths, linker paths or source files not being applied.
     message(FATAL_ERROR "You define a component the same name as the Target Project ${COMP_NAME}. This is not allowed so please change either one.")
  endif()

  set(CREATED FALSE)
  if(NOT TARGET ${COMP_NAME})
  
    set(CREATED TRUE)
    add_library(${COMP_NAME} INTERFACE)
    if("${TARGET_PROJECT}" MATCHES "^${COMP_NAME}_unit.*" OR ("${COMP_NAME}" MATCHES "^${TARGET_PROJECT}.*" AND NOT "${TARGET_PROJECT}" MATCHES "_unit_"))
      message(STATUS "Component '${COMP_NAME}' has been identify to be part of the project '${TARGET_PROJECT}'. Treating as project-specific with ROOT_PATH equal to PROJECT_PATH")
      set(ROOT ".")
    else()
      set(ROOT "dependencies/${COMP_NAME}")
      target_include_directories(${COMP_NAME} INTERFACE "${ROOT}")
    endif()
    string(TOLOWER "${COMP_NAME}" COMP_LOWER)
    set(GROUP_NAME "${GROUP}/${COMP_NAME}")
    set_property(GLOBAL PROPERTY ${COMP_LOWER}_GROUP "${GROUP_NAME}")
    set_property(GLOBAL PROPERTY ${COMP_LOWER}_INCLUDES "${ROOT}")
    set_property(GLOBAL APPEND PROPERTY COMPONENT_REGISTRY "${COMP_NAME}")
    
    set(FILES "")
    set(FILE_GROUPS "")
    set(CURRENT_SUBGROUP "")
    foreach(ITEM ${DIC_UNPARSED_ARGUMENTS})
      if(ITEM MATCHES "^\\*\\*(.+)$")
        set(CURRENT_SUBGROUP "${CMAKE_MATCH_1}")
      else()
        list(APPEND FILES "${ROOT}/${ITEM}")
        if(CURRENT_SUBGROUP)
          list(APPEND FILE_GROUPS "${ROOT}/${ITEM}=${GROUP_NAME}/${CURRENT_SUBGROUP}")
        endif()
      endif()
    endforeach()
    set_property(GLOBAL APPEND PROPERTY ${COMP_LOWER}_FILES ${FILES})
    if(FILE_GROUPS)
      set_property(GLOBAL APPEND PROPERTY ${COMP_LOWER}_FILE_GROUPS ${FILE_GROUPS})
    endif()
  endif()
  
  set(${COMP_NAME}_CREATED ${CREATED} PARENT_SCOPE)
endfunction()

#------------------------------------------------------------------------------
# Function: ProcessComponents
# Purpose: Links components to the main executable, adds sources, includes, linker paths.
# Parameters:
# - TARGET (optional): Target to link components to (defaults to ${TARGET_PROJECT}).
# Usage:
#   ProcessComponents()
#   ProcessComponents(custom_target)
#------------------------------------------------------------------------------
function(ProcessComponents)
  set(options)
  set(oneValueArgs TARGET)
  set(multiValueArgs)
  cmake_parse_arguments(PC "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
  
  if(NOT PC_TARGET)
    if(NOT TARGET_PROJECT)
      message(FATAL_ERROR "TARGET_PROJECT must be defined for ProcessComponents. "
                          "Example: set(TARGET_PROJECT \"my_project\")")
    endif()
    set(PC_TARGET "${TARGET_PROJECT}")
  endif()

if(EXISTS "${CMAKE_SOURCE_DIR}/dependencies")
  set(BAT_SRC "${CMAKE_BINARY_DIR}/_deps/xcmake_tools/check_changes.bat")
  set(BAT_DEST "${CMAKE_SOURCE_DIR}/dependencies/check_changes.bat")
  if(EXISTS "${BAT_SRC}" AND NOT EXISTS "${BAT_DEST}")
    file(COPY_FILE "${BAT_SRC}" "${BAT_DEST}")
    message(STATUS "Copied check_changes.bat from xcmake_tools to dependencies folder.")
  endif()
endif()
  
  get_property(REG GLOBAL PROPERTY COMPONENT_REGISTRY)
  message(STATUS "Processing: ${REG}")

  foreach(COMP ${REG})
    string(TOLOWER "${COMP}" COMP_LOWER)

    get_property(FILES GLOBAL PROPERTY ${COMP_LOWER}_FILES)
    if(FILES)
      target_sources(${PC_TARGET} PRIVATE ${FILES})

      get_property(GROUP GLOBAL PROPERTY ${COMP_LOWER}_GROUP)
      if(GROUP)
        # Apply default group for files without subgroups
        set(UNGROUPED_FILES "${FILES}")

        get_property(FILE_GROUPS GLOBAL PROPERTY ${COMP_LOWER}_FILE_GROUPS)
        if(FILE_GROUPS)
          foreach(FILE_GROUP ${FILE_GROUPS})
            string(REGEX MATCH "^(.+)=(.+)$" MATCH "${FILE_GROUP}")
            if(MATCH)
              set(FILE_PATH "${CMAKE_MATCH_1}")
              set(SUBGROUP "${CMAKE_MATCH_2}")
              source_group("${SUBGROUP}" FILES "${FILE_PATH}")
              list(REMOVE_ITEM UNGROUPED_FILES "${FILE_PATH}")
            endif()
          endforeach()
        endif()
        
        # Apply default group to remaining files
        source_group("${GROUP}" FILES ${UNGROUPED_FILES})
      endif()
    else()
      message(WARNING "No files defined for component ${COMP}. Skipping.")
    endif()

    get_property(INCS GLOBAL PROPERTY ${COMP_LOWER}_INCLUDES)
    if(INCS)
      # message(STATUS "Applying include directories for ${COMP}: ${INCS}")
      target_include_directories(${PC_TARGET} PRIVATE ${INCS})
    endif()

    get_property(LINK_PATHS GLOBAL PROPERTY ${COMP_LOWER}_LINKER_PATHS)
    if(LINK_PATHS)
      message(STATUS "Applying linker paths for ${COMP}: ${LINK_PATHS}")
      target_link_directories(${PC_TARGET} PRIVATE ${LINK_PATHS})
    endif()
  endforeach()
endfunction()

#------------------------------------------------------------------------------
# Function: AppendComponentIncludes
# Purpose: Appends additional include directories to a component's ${COMP_NAME}_INCLUDES property.
# Parameters:
# - COMP_NAME: Component name (e.g., xcompression).
# - ARGN: List of include directories to append.
# Usage:
#   AppendComponentIncludes(xcompression "${CMAKE_SOURCE_DIR}/dependencies/zstd")
#------------------------------------------------------------------------------
function(AppendComponentIncludes COMP_NAME)
  string(TOLOWER "${COMP_NAME}" COMP_LOWER)
  get_property(CURRENT_INCLUDES GLOBAL PROPERTY ${COMP_LOWER}_INCLUDES)
  list(APPEND CURRENT_INCLUDES ${ARGN})
  set_property(GLOBAL PROPERTY ${COMP_LOWER}_INCLUDES "${CURRENT_INCLUDES}")
endfunction()

#------------------------------------------------------------------------------
# Function: SetComponentGroup
# Purpose: Sets the IDE group for a component's ${COMP_NAME}_GROUP property.
# Parameters:
# - COMP_NAME: Component name (e.g., xcompression).
# - GROUP: IDE group path (e.g., "dependencies/xcore/xcompression").
# Usage:
#   SetComponentGroup(xcompression "dependencies/xcore/xcompression")
#------------------------------------------------------------------------------
function(SetComponentGroup COMP_NAME GROUP)
  string(TOLOWER "${COMP_NAME}" COMP_LOWER)
  set_property(GLOBAL PROPERTY ${COMP_LOWER}_GROUP "${GROUP}")
endfunction()

#------------------------------------------------------------------------------
# Function: AppendComponentLinkerPaths
# Purpose: Appends linker paths to a component's ${COMP_NAME}_LINKER_PATHS property.
# Parameters:
# - COMP_NAME: Component name (e.g., xcompression).
# - ARGN: List of linker paths to append.
# Usage:
#   AppendComponentLinkerPaths(xcompression "${CMAKE_SOURCE_DIR}/dependencies/zstd/build-cmake/lib/Release")
#------------------------------------------------------------------------------
function(AppendComponentLinkerPaths COMP_NAME)
  string(TOLOWER "${COMP_NAME}" COMP_LOWER)
  get_property(CURRENT_LINKER_PATHS GLOBAL PROPERTY ${COMP_LOWER}_LINKER_PATHS)
  list(APPEND CURRENT_LINKER_PATHS ${ARGN})
  set_property(GLOBAL PROPERTY ${COMP_LOWER}_LINKER_PATHS "${CURRENT_LINKER_PATHS}")
endfunction()