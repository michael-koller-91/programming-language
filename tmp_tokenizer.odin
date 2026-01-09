// run: odin run tmp_tokenizer.odin -file
package main

import "core:fmt"
import "core:log"
import "core:os"
import "core:testing"
import "core:unicode"

Loc :: struct {
	line_nr: int,
	column:  int,
}


Token2_Kind :: enum {
	EOF,
	Identifier,
	L_Par,
	R_Par,
	Plus,
	Integer,
}

Token2 :: struct {
	filename: string,
	line:     string,
	loc:      Loc,
	kind:     Token2_Kind,
	word:     string,
}

Scanner :: struct {
	filename:   string,
	src:        string,
	line_nr:    int,
	line_start: int, // where did the current line start
	//ch_read:    int, // number of characters already read
	curr:       int, // current offset
	ch:         rune, // character at current offset
}

// advance the scanner by one character
consume_ch :: proc(scanner: ^Scanner) {
	if scanner.curr + 1 < len(scanner.src) {
		scanner.curr += 1
		scanner.ch = rune(scanner.src[scanner.curr])
	} else {
		scanner.curr = len(scanner.src)
		scanner.ch = -1
	}
}

// consume as long as there are valid identifier characters
consume_identifier :: proc(scanner: ^Scanner) -> string {
	curr := scanner.curr
	for unicode.is_letter(scanner.ch) || unicode.is_digit(scanner.ch) || scanner.ch == '_' {
		consume_ch(scanner)
	}
	return scanner.src[curr:scanner.curr]
}

consume_integer :: proc(scanner: ^Scanner) -> string {
	curr := scanner.curr
	for unicode.is_digit(scanner.ch) || scanner.ch == '_' {
		consume_ch(scanner)
	}
	return scanner.src[curr:scanner.curr]
}

get_line :: proc(scanner: ^Scanner) -> string {
	return scanner.src[scanner.line_start:scanner.curr]
}

get_token :: proc(scanner: ^Scanner) -> Token2 {
	// skip white spaces
	for unicode.is_white_space(scanner.ch) {
		if scanner.ch == '\n' {
			scanner.line_nr += 1
			scanner.line_start = scanner.curr + 1
		}
		consume_ch(scanner)
	}
	ch := scanner.ch

	kind := Token2_Kind.EOF
	word := ""
	line := ""
	loc := Loc {
		line_nr = scanner.line_nr,
		column  = scanner.curr + 1 - scanner.line_start,
	}

	switch true {
	case unicode.is_letter(ch):
		kind = .Identifier
		word = consume_identifier(scanner)
		line = get_line(scanner)
	case unicode.is_digit(ch):
		kind = .Integer
		word = consume_integer(scanner)
		line = get_line(scanner)
	case:
		consume_ch(scanner)

		switch ch {
		case -1:
		case '+':
			word = "+"
			line = get_line(scanner)
			kind = .Plus
		case '(':
			word = "("
			line = get_line(scanner)
			kind = .L_Par
		case ')':
			word = ")"
			line = get_line(scanner)
			kind = .R_Par
		case:
			fmt.eprintfln("[CERROR] Not a supported character: %q", ch)
			os.exit(1)
		}
	}

	return Token2{filename = scanner.filename, line = line, loc = loc, word = word, kind = kind}
}

// convert src into tokens
tokenize :: proc(scanner: ^Scanner) -> []Token2 {
	tokens: [dynamic]Token2
	for {
		token := get_token(scanner)
		append(&tokens, token)
		if token.kind == .EOF {
			break
		}
	}
	log.debugf("found %v tokens in file %v", len(tokens), scanner.filename)
	return tokens[:]
}
