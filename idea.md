## Problem Statement:
Sanitizers are an effective way to find race conditions, undefined behavior, and memory leaks, among other things, in multi-threaded, complex code. However, these tools produce messy outputs of deep stack traces paired with memory addresses. The goal of this tool is to provide the user easy nvim motions for working with these tools in a more user-friendly manner.

This plugin will interface directly with existing CMake config or through a desired C/C++ compiler for the single-file case, including compile flags for the sanitizer of choosing. Similar to cmake-tools.nvim, a floating window in the top right corner will appear with status code upon completion, and in the case of test failure, a large centered floating window will appear with the troublesome lines of code, allowing for easy navigation to them, providing the accompanying error message inline.

## Desired Interface:
All actions done through either:
- a vim command (i.e. :sancompile)
- a custom command prompt line (see cmake-tools.nvim)
- <leader> keystroke (less likely)

- possible interface similar to lazygit, allowing for interactive navigation of sanitizer results through a popup window.

Note that the builds/runs will be asynchronous, not blocking the editor

## Config
We need to support user-defined compile flags.
- i.e. -O3 -Wall
We can read project-level Makefiles, CMake presets for this. Can this be done on startup (i.e. logic in plugin folder). If no such files are present, we can provide a set of default compile flags.

Additional config considerations:
- Sanitizer-specific environment variables (ASAN_OPTIONS, TSAN_OPTIONS, etc.)
- Separate build directory for sanitizer builds to avoid clobbering the normal build
- Default sanitizer selection per-project

For projects that have a `CMakeLists.txt` in the root directory, CTest will be used, and g++/gcc otherwise. The idea is that either way, the output will be nicely formatted.

CMake support will be prioritized. Also, g++ support will be secondary; clang++ diagnostics will provide a heightened user experience.

## Commands
- :San build <sanitizer> [target]
    - Compiles current file in case of single-file case, or configures CMake with the given sanitizer. Optional target builds only that CMake target; omit to build all.
- :San run [target]
    - Runs CTest or the compiled binary. Parses sanitizer output on completion. Optional target runs only that CTest target; omit to run all.
- :San results
    - Reopen the results window from the last run.
- :San clear
    - Clear all sanitizer diagnostics from the current buffer.
- :San stop
    - Kill a running sanitizer build.
- :San hook <install, remove>
    - Install or remove a git pre-commit hook that runs the sanitizer check. See more on this feature below.

## Non-Goals
- This plugin is not a debugger. It will not support breakpoints, stepping, variable inspection, or attaching to running processes. Use nvim-dap for that. This plugin finds bugs; nvim-dap helps you understand them.

## Feature Ideas
- pre-commit hook, allowing the user to optionally wire this flow into git hooks

## Proposed Components
- *Parser*: formatting sanitizer output
- *Runner*: asynchronous execution of tests / file
- *UI/popup manager*: manage lifecycle of floating windows
- *Diagnostics manager*: feeds results to vim.diagnostic for inline errors
- *Config*: manage user config / sanitizer-specific env vars
- *Build manager*: manage sanitizer builds in separate directory
- *Hook manager*: not in scope currently


