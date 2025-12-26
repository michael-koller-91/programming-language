package main

import "core:fmt"
import "core:log"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:unicode"

Token :: struct {
	filename: string,
	line:     string,
	word:     string,
	line_nr:  int,
	offset:   int,
	type:     TokenType,
	value:    union {
		int,
		f64,
	},
}

TokenType :: enum {
	Lpar, // (
	Rpar, // )
	Int,
	Float,
	Name,
	Plus,
	Minus,
	Mult,
}

is_seperator :: proc(r: rune) -> (is_sep: bool) {
	is_sep = false
	seperators := [?]rune{'+', ' ', '\t', '(', ')'}
	for sep in seperators {
		if r == sep {
			is_sep = true
			return
		}
	}
	return
}

tokenize_file :: proc(filepath: string) -> []Token {
	data, ok := os.read_entire_file(filepath, context.allocator)
	defer delete(data, context.allocator)

	if ok {
		log.info("Read file", filepath)
	} else {
		fmt.eprintln("[ERROR] Could not read file", filepath)
		os.exit(-1)
	}

	tokens: [dynamic]Token
	line_number := 0
	it := string(data)
	for line in strings.split_lines_iterator(&it) {
		line_number += 1
		start := 0
		end := 0

		ch_next := rune('.')
		for i in 0 ..< len(line) {
			ch := rune(line[i])
			if i + 1 < len(line) {
				ch_next = rune(line[i + 1])
			} else {
				ch_next = rune(' ')
			}

			switch (ch) {
			case '\t', '\n', '\v', '\f', '\r', ' ', 0x85, 0xa0:
				start = i + 1
				continue
			case '+':
				t := Token {
					filename = filepath,
					line     = strings.clone(line),
					word     = strings.clone("+"),
					line_nr  = line_number,
					offset   = i,
					type     = TokenType.Plus,
				}
				append(&tokens, t)
				start = i + 1
				continue
			case '-':
				t := Token {
					filename = filepath,
					line     = strings.clone(line),
					word     = strings.clone("-"),
					line_nr  = line_number,
					offset   = i,
					type     = TokenType.Minus,
				}
				append(&tokens, t)
				start = i + 1
				continue
			case '*':
				t := Token {
					filename = filepath,
					line     = strings.clone(line),
					word     = strings.clone("*"),
					line_nr  = line_number,
					offset   = i,
					type     = TokenType.Mult,
				}
				append(&tokens, t)
				start = i + 1
				continue
			case '(':
				t := Token {
					filename = filepath,
					line     = strings.clone(line),
					word     = strings.clone("("),
					line_nr  = line_number,
					offset   = i,
					type     = TokenType.Lpar,
				}
				append(&tokens, t)
				start = i + 1
				continue
			case ')':
				t := Token {
					filename = filepath,
					line     = strings.clone(line),
					word     = strings.clone(")"),
					line_nr  = line_number,
					offset   = i,
					type     = TokenType.Rpar,
				}
				append(&tokens, t)
				start = i + 1
				fmt.println("add ), continue, start=", start)
				continue
			case:
				if is_seperator(ch_next) {
					end = i
					t := Token {
						filename = filepath,
						line     = strings.clone(line),
						word     = strings.clone(line[start:end + 1]),
						line_nr  = line_number,
						offset   = start,
					}
					if unicode.is_digit(rune(line[start])) {
						n, ok := strconv.parse_int(t.word)
						if ok {
							t.type = TokenType.Int
							t.value = n
						} else {
							n, ok := strconv.parse_f64(t.word)
							if ok {
								t.type = TokenType.Float
								t.value = n
							} else {
								fmt.eprintfln(
									"[ERROR] Could not parse '%s' as int or float. Only these two types can start with a digit.",
									t.word,
								)
								os.exit(-1)
							}
						}
					} else {
						t.type = TokenType.Name
					}
					start = i + 1
					append(&tokens, t)
					continue
				}
			}
		}
	}
	log.info("Finished tokenizing", filepath)
	return tokens[:]
}

delete_tokens :: proc(tokens: []Token) {
	for t in tokens {
		delete(t.line)
		delete(t.word)
	}
	delete(tokens)
}

main :: proc() {
	context.logger = log.create_console_logger()

	tokens := tokenize_file("programs/02_add.prola")
	defer delete_tokens(tokens)

	for t in tokens {fmt.println(t)}
}
