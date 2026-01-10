package main

import "core:testing"

@(test)
test_tokenize_src_01 :: proc(t: ^testing.T) {
	src := "foo(1 + 23  )\nbar(   baz(	))"

	scanner := init_scanner("", src)

	tokens := tokenize_src(&scanner)
	defer delete_tokens2(tokens)

	testing.expect_value(t, len(tokens), 13)

	testing.expect_value(t, tokens[0].kind, Token2_Kind.Identifier)
	testing.expect_value(t, tokens[1].kind, Token2_Kind.L_Par)
	testing.expect_value(t, tokens[2].kind, Token2_Kind.Integer)
	testing.expect_value(t, tokens[3].kind, Token2_Kind.Add)
	testing.expect_value(t, tokens[4].kind, Token2_Kind.Integer)
	testing.expect_value(t, tokens[5].kind, Token2_Kind.R_Par)
	testing.expect_value(t, tokens[6].kind, Token2_Kind.Identifier)
	testing.expect_value(t, tokens[7].kind, Token2_Kind.L_Par)
	testing.expect_value(t, tokens[8].kind, Token2_Kind.Identifier)
	testing.expect_value(t, tokens[9].kind, Token2_Kind.L_Par)
	testing.expect_value(t, tokens[10].kind, Token2_Kind.R_Par)
	testing.expect_value(t, tokens[11].kind, Token2_Kind.R_Par)
	testing.expect_value(t, tokens[12].kind, Token2_Kind.EOF)

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
	testing.expect_value(t, tokens[12].line, "")

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
	testing.expect_value(t, tokens[12].word, "")

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
	testing.expect_value(t, tokens[12].loc.line_nr, 2)

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
	testing.expect_value(t, tokens[12].loc.column, 15)
}

@(test)
test_tokenize_src_02 :: proc(t: ^testing.T) {
	src := ""

	scanner := init_scanner("", src)

	tokens := tokenize_src(&scanner)
	defer delete_tokens2(tokens)

	testing.expect_value(t, len(tokens), 1)

	testing.expect_value(t, tokens[0].kind, Token2_Kind.EOF)
	testing.expect_value(t, tokens[0].line, "")
	testing.expect_value(t, tokens[0].word, "")
	testing.expect_value(t, tokens[0].loc.line_nr, 1)
	testing.expect_value(t, tokens[0].loc.column, 1)
}
