package main

import "core:testing"

@(test)
test_01 :: proc(t: ^testing.T) {
	filename := "programs/01_tokens.prola"
	tokens := tokenize_file(filename)
	defer delete_tokens(tokens)

	testing.expect_value(t, len(tokens), 21 + 7)

	line_nr := 0
	for token in tokens {
		testing.expect_value(t, token.filename, filename)
	}

	testing.expect_value(t, tokens[0].word, "a")
	testing.expect_value(t, tokens[0].offset, 0)
	testing.expect_value(t, tokens[1].word, "b")
	testing.expect_value(t, tokens[1].offset, 0)
	testing.expect_value(t, tokens[2].word, "c")
	testing.expect_value(t, tokens[2].offset, 0)
	testing.expect_value(t, tokens[3].word, "d")
	testing.expect_value(t, tokens[3].offset, 1)
	testing.expect_value(t, tokens[4].word, "e")
	testing.expect_value(t, tokens[4].offset, 2)
	testing.expect_value(t, tokens[5].word, "f")
	testing.expect_value(t, tokens[5].offset, 2)
	testing.expect_value(t, tokens[6].word, "g")
	testing.expect_value(t, tokens[6].offset, 2)

	testing.expect_value(t, tokens[7].word, "aa")
	testing.expect_value(t, tokens[7].offset, 0)
	testing.expect_value(t, tokens[8].word, "bb")
	testing.expect_value(t, tokens[8].offset, 0)
	testing.expect_value(t, tokens[9].word, "cc")
	testing.expect_value(t, tokens[9].offset, 0)
	testing.expect_value(t, tokens[10].word, "dd")
	testing.expect_value(t, tokens[10].offset, 1)
	testing.expect_value(t, tokens[11].word, "ee")
	testing.expect_value(t, tokens[11].offset, 2)
	testing.expect_value(t, tokens[12].word, "ff")
	testing.expect_value(t, tokens[12].offset, 2)
	testing.expect_value(t, tokens[13].word, "gg")
	testing.expect_value(t, tokens[13].offset, 2)

	testing.expect_value(t, tokens[14].word, "aa")
	testing.expect_value(t, tokens[14].offset, 0)
	testing.expect_value(t, tokens[15].word, "AA")
	testing.expect_value(t, tokens[15].offset, 3)
	testing.expect_value(t, tokens[16].word, "bb")
	testing.expect_value(t, tokens[16].offset, 0)
	testing.expect_value(t, tokens[17].word, "BB")
	testing.expect_value(t, tokens[17].offset, 3)
	testing.expect_value(t, tokens[18].word, "cc")
	testing.expect_value(t, tokens[18].offset, 0)
	testing.expect_value(t, tokens[19].word, "CC")
	testing.expect_value(t, tokens[19].offset, 4)
	testing.expect_value(t, tokens[20].word, "dd")
	testing.expect_value(t, tokens[20].offset, 1)
	testing.expect_value(t, tokens[21].word, "DD")
	testing.expect_value(t, tokens[21].offset, 4)
	testing.expect_value(t, tokens[22].word, "ee")
	testing.expect_value(t, tokens[22].offset, 2)
	testing.expect_value(t, tokens[23].word, "EE")
	testing.expect_value(t, tokens[23].offset, 5)
	testing.expect_value(t, tokens[24].word, "ff")
	testing.expect_value(t, tokens[24].offset, 2)
	testing.expect_value(t, tokens[25].word, "FF")
	testing.expect_value(t, tokens[25].offset, 5)
	testing.expect_value(t, tokens[26].word, "gg")
	testing.expect_value(t, tokens[26].offset, 2)
	testing.expect_value(t, tokens[27].word, "GG")
	testing.expect_value(t, tokens[27].offset, 5)
}
