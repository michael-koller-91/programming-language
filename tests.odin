package main

import "base:runtime"
import "core:testing"

@(test)
test_program_01 :: proc(t: ^testing.T) {
	file_in_path := "programs/01_arithmetics.prola"

	file_out_base := compile_file(file_in_path)
	defer delete(file_out_base)

	build_executable(file_out_base)

	stdout, stderr, ok := run_executable(file_out_base)
	defer delete(stdout)
	defer delete(stderr)

	expected_stderr := ""
	expected_stdout := "1\n5\n15\n34\n6\n120\n5040\n14\n10\n"

	testing.expectf(
		t,
		runtime.string_eq(stderr, expected_stderr),
		"Program should not write to stderr but got: %v",
		stderr,
	)
	testing.expectf(
		t,
		runtime.string_eq(stdout, expected_stdout),
		"Expected stdout is wrong.\nProgram wrote:\n%v\nProgram should have written:\n%v",
		stdout,
		expected_stdout,
	)
}
