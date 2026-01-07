// run: odin run tmp_tokenizer.tmp -file
package foo

import "core:fmt"
import "core:log"
import "core:unicode"

Loc :: struct {
	line_nr: int,
	column:  int,
}


Token_Kind :: enum {
	EOF,
	Identifier,
	L_Par,
	R_Par,
	Plus,
	Integer,
}

Token :: struct {
	filename: string,
	//line:     string,
	//loc:      Loc,
	kind:     Token_Kind,
	word:     string,
}

Scanner :: struct {
	filename:   string,
	src:        string,
	line_start: int, // where did the current line start
	//ch_read:    int, // number of characters already read
	curr:       int, // current offset
	ch:         rune, // character at current offset
}

consume_ch :: proc(scanner: ^Scanner) {
	if scanner.curr + 1 == len(scanner.src) {
		scanner.ch = -1 // should
	} else {
		fmt.println("consuming with curr =", scanner.curr)
		scanner.curr += 1
		scanner.ch = rune(scanner.src[scanner.curr])
	}
}

get_identifier :: proc(scanner: ^Scanner) -> string {
	curr := scanner.curr
	for unicode.is_letter(scanner.ch) || unicode.is_digit(scanner.ch) {
		fmt.println("consuming", scanner.ch)
		consume_ch(scanner)
	}
	return scanner.src[curr:scanner.curr]
}

get_token :: proc(scanner: ^Scanner) -> Token {
	ch := scanner.ch
	switch true {
	case unicode.is_letter(ch):
		word := get_identifier(scanner)
		return Token{filename = scanner.filename, word = word, kind = .Identifier}
	}
	return Token{filename = scanner.filename, word = "no word"}
}

main :: proc() {
	context.logger = log.create_console_logger()

	//src := "print(1+2)\nfoo(bar())"
	src := "print(1+2)"
	scanner := Scanner {
		filename   = "not a file",
		src        = src,
		line_start = 0,
		curr       = 0,
		ch         = rune(src[0]),
	}
	token := get_token(&scanner)
	fmt.println("token =", token)
}
