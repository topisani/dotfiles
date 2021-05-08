# Version 3.8 is required for c++17
cmake_minimum_required(VERSION 3.8)

set(CMAKE_CXX_EXTENSIONS OFF)
set(EXECUTABLE_OUTPUT_PATH ..)
set(LIBRARY_OUTPUT_PATH ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_BUILD_TYPE Debug)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

set(CMAKE_CXX_STANDARD 17)

link_libraries(xcb xcb-util xcb-icccm xcb-ewmh wm)

add_executable(wname util.cpp wname.cpp)
add_executable(tinywm tinywm.cpp)
add_executable(type type.cpp util.cpp)
add_executable(chwso chwso.cpp util.cpp)

