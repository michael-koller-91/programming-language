// run: odin run tmp_tokenizer.odin -file
package foo

import "core:fmt"
import "core:log"
import "core:os"
import "core:unicode"

Loc :: struct {
	line_nr: int,
	column:  int,
}


Token_Kind :: enum {
	EOF,
	New_Line,
	Identifier,
	L_Par,
	R_Par,
	Plus,
	Integer,
}

Token :: struct {
	filename: string,
	line:     string,
	//loc:      Loc,
	line_nr:  int,
	kind:     Token_Kind,
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

consume_ch :: proc(scanner: ^Scanner) {
	if scanner.curr + 1 < len(scanner.src) {
		scanner.curr += 1
		scanner.ch = rune(scanner.src[scanner.curr])
	} else {
		scanner.curr = len(scanner.src)
		scanner.ch = -1
	}
}

get_identifier :: proc(scanner: ^Scanner) -> string {
	curr := scanner.curr
	for unicode.is_letter(scanner.ch) || unicode.is_digit(scanner.ch) || scanner.ch == '_' {
		consume_ch(scanner)
	}
	return scanner.src[curr:scanner.curr]
}

get_integer :: proc(scanner: ^Scanner) -> string {
	curr := scanner.curr
	for unicode.is_digit(scanner.ch) || scanner.ch == '_' {
		consume_ch(scanner)
	}
	return scanner.src[curr:scanner.curr]
}

get_line :: proc(scanner: ^Scanner) -> string {
	return scanner.src[scanner.line_start:scanner.curr]
}

get_token :: proc(scanner: ^Scanner) -> Token {
	ch := scanner.ch

	kind := Token_Kind.EOF
	line_nr := scanner.line_nr
	word := ""
	line := ""

	switch true {
	case unicode.is_letter(ch):
		kind = .Identifier
		word = get_identifier(scanner)
		line = get_line(scanner)
	case unicode.is_digit(ch):
		kind = .Integer
		word = get_integer(scanner)
		line = get_line(scanner)
	case:
		consume_ch(scanner)
		switch ch {
		case -1:
		case '\n':
			scanner.line_nr += 1
			scanner.line_start = scanner.curr
			kind = .New_Line
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

	return Token {
		filename = scanner.filename,
		line = line,
		line_nr = line_nr,
		word = word,
		kind = kind,
	}
}

main :: proc() {
	context.logger = log.create_console_logger()

	src := "print(1+23)\nfoo(bar())"
	scanner := Scanner {
		filename   = "",
		src        = src,
		line_nr    = 1,
		line_start = 0,
		curr       = 0,
		ch         = rune(src[0]),
	}
	for {
		token := get_token(&scanner)
		fmt.println("token =", token)
		if token.kind == .EOF {
			break
		}
	}
}
