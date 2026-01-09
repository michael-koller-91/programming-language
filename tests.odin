package main

import "base:runtime"
import "core:testing"

//@(test)
test_program_01 :: proc(t: ^testing.T) {
	file_in_path := "programs/01_arithmetics.prola"

	file_out_base := compile_file(file_in_path)
	defer delete(file_out_base)

	build_executable(file_out_base)

	stdout, stderr, ok := run_executable(file_out_base)
	defer delete(stdout)
	defer delete(stderr)

	expected_stderr := ""
	expected_stdout := "1\n5\n15\n34\n-1\n5\n-2\n6\n120\n5040\n2\n3\n1\n14\n10\n"

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

@(test)
test_tokenize_01 :: proc(t: ^testing.T) {
	src := "foo(1 + 23  )\nbar(   baz(	))"

	scanner := Scanner {
		filename   = "",
		src        = src,
		line_nr    = 1,
		line_start = 0,
		curr       = 0,
		ch         = rune(src[0]),
	}

	tokens := tokenize(&scanner)
	defer delete(tokens)

	testing.expect_value(t, tokens[0].kind, Token2_Kind.Identifier)
	testing.expect_value(t, tokens[1].kind, Token2_Kind.L_Par)
	testing.expect_value(t, tokens[2].kind, Token2_Kind.Integer)
	testing.expect_value(t, tokens[3].kind, Token2_Kind.Plus)
	testing.expect_value(t, tokens[4].kind, Token2_Kind.Integer)
	testing.expect_value(t, tokens[5].kind, Token2_Kind.R_Par)
	testing.expect_value(t, tokens[6].kind, Token2_Kind.Identifier)
	testing.expect_value(t, tokens[7].kind, Token2_Kind.L_Par)
	testing.expect_value(t, tokens[8].kind, Token2_Kind.Identifier)
	testing.expect_value(t, tokens[9].kind, Token2_Kind.L_Par)
	testing.expect_value(t, tokens[10].kind, Token2_Kind.R_Par)
	testing.expect_value(t, tokens[11].kind, Token2_Kind.R_Par)

	testing.expect_value(t, tokens[0].line, "foo")
	testing.expect_value(t, tokens[1].line, "foo(")
	testing.expect_value(t, tokens[2].line, "foo(1")
	testing.expect_value(t, tokens[3].line, "foo(1 +")
	testing.expect_value(t, tokens[4].line, "foo(1 + 23")
	testing.expect_value(t, tokens[5].line, "foo(1 + 23  )")
	testing.expect_value(t, tokens[6].line, "bar")
	testing.expect_value(t, tokens[7].line, "bar(")
	testing.expect_value(t, tokens[8].line, "bar(   baz")
	testing.expect_value(t, tokens[9].line, "bar(   baz(")
	testing.expect_value(t, tokens[10].line, "bar(   baz(	)")
	testing.expect_value(t, tokens[11].line, "bar(   baz(	))")

	testing.expect_value(t, tokens[0].word, "foo")
	testing.expect_value(t, tokens[1].word, "(")
	testing.expect_value(t, tokens[2].word, "1")
	testing.expect_value(t, tokens[3].word, "+")
	testing.expect_value(t, tokens[4].word, "23")
	testing.expect_value(t, tokens[5].word, ")")
	testing.expect_value(t, tokens[6].word, "bar")
	testing.expect_value(t, tokens[7].word, "(")
	testing.expect_value(t, tokens[8].word, "baz")
	testing.expect_value(t, tokens[9].word, "(")
	testing.expect_value(t, tokens[10].word, ")")
	testing.expect_value(t, tokens[11].word, ")")

	testing.expect_value(t, tokens[0].loc.line_nr, 1)
	testing.expect_value(t, tokens[1].loc.line_nr, 1)
	testing.expect_value(t, tokens[2].loc.line_nr, 1)
	testing.expect_value(t, tokens[3].loc.line_nr, 1)
	testing.expect_value(t, tokens[4].loc.line_nr, 1)
	testing.expect_value(t, tokens[5].loc.line_nr, 1)
	testing.expect_value(t, tokens[6].loc.line_nr, 2)
	testing.expect_value(t, tokens[7].loc.line_nr, 2)
	testing.expect_value(t, tokens[8].loc.line_nr, 2)
	testing.expect_value(t, tokens[9].loc.line_nr, 2)
	testing.expect_value(t, tokens[10].loc.line_nr, 2)
	testing.expect_value(t, tokens[11].loc.line_nr, 2)

	testing.expect_value(t, tokens[0].loc.column, 1)
	testing.expect_value(t, tokens[1].loc.column, 4)
	testing.expect_value(t, tokens[2].loc.column, 5)
	testing.expect_value(t, tokens[3].loc.column, 7)
	testing.expect_value(t, tokens[4].loc.column, 9)
	testing.expect_value(t, tokens[5].loc.column, 13)
	testing.expect_value(t, tokens[6].loc.column, 1)
	testing.expect_value(t, tokens[7].loc.column, 4)
	testing.expect_value(t, tokens[8].loc.column, 8)
	testing.expect_value(t, tokens[9].loc.column, 11)
	testing.expect_value(t, tokens[10].loc.column, 13)
	testing.expect_value(t, tokens[11].loc.column, 14)
}
