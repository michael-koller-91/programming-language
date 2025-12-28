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
	kind:     Token_Kind,
	value:    union {
		int,
		f64,
	},
}

Token_Kind :: enum {
	Lpar, // (
	Rpar, // )
	Int,
	Float,
	Name,
	Builtin,
	Plus,
	Minus,
	Mult,
}

Parser :: struct {
	tokens: ^[]Token,
	pos:    int,
}

Expr_Kind :: enum {
	Plus,
	Constant_Int,
}

Expr_Plus :: struct {
	left:  Expr,
	right: Expr,
}

Expr_Const_Int :: struct {
	value: int,
}

Expr :: union {
	^Expr_Plus,
	^Expr_Const_Int,
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
					kind     = Token_Kind.Plus,
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
					kind     = Token_Kind.Minus,
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
					kind     = Token_Kind.Mult,
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
					kind     = Token_Kind.Lpar,
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
					kind     = Token_Kind.Rpar,
				}
				append(&tokens, t)
				start = i + 1
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
							t.kind = Token_Kind.Int
							t.value = n
						} else {
							n, ok := strconv.parse_f64(t.word)
							if ok {
								t.kind = Token_Kind.Float
								t.value = n
							} else {
								fmt.eprintln(line)
								for i in 0 ..< start {
									fmt.eprint(" ")
								}
								fmt.eprintln("^")
								fmt.eprintfln(
									"%s:%d:%d [ERROR] Could not parse as int or float.",
									t.filename,
									t.line_nr,
									start,
								)
								os.exit(-1)
							}
						}
					} else {
						if t.word == "print" {
							t.kind = Token_Kind.Builtin
						} else {
							t.kind = Token_Kind.Name
						}
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

parse_constant :: proc(parser: ^Parser) -> Expr {
	t := &parser.tokens[parser.pos]
	parser.pos += 1
	expr := new(Expr_Const_Int, context.temp_allocator)
	expr.value = t.value.?
	log.info("( pos =", parser.pos - 1, ") constant =", t.value)
	return expr
}

parse_plus :: proc(parser: ^Parser) -> Expr {
	left := parse_constant(parser)
	if left == nil {return nil}
	if parser.pos < len(parser.tokens) && parser.tokens[parser.pos].kind == Token_Kind.Plus {
		parser.pos += 1
		right := parse_plus(parser)
		if right == nil {return nil}
		expr := new(Expr_Plus, context.temp_allocator)
		expr.left = left
		expr.right = right
		log.info("( pos =", parser.pos - 1, ") return new expr")
		return expr
	}
	log.info("( pos =", parser.pos, ") return left")
	return left
}

print_tree :: proc(expr: Expr, depth: int) -> int {
	for i in 0 ..< 2 * depth {fmt.print(" ")}
	d := depth + 1

	switch e in expr {
	case ^Expr_Plus:
		fmt.println("Plus:")
		print_tree(e^.left, d)
		print_tree(e^.right, d)
		return d - 1
	case ^Expr_Const_Int:
		fmt.println("Const:", e^.value)
		return d - 1
	}
	return 0
}

main :: proc() {
	context.logger = log.create_console_logger()

	tokens := tokenize_file("programs/02_add.prola")
	defer delete_tokens(tokens)

	for t in tokens {
		fmt.println(t)
	}

	parser := Parser {
		tokens = &tokens,
		pos    = 0,
	}

	expr := parse_plus(&parser)

	print_tree(expr, 0)

	defer free_all(context.temp_allocator)

	//fmt.println()

	//fmt.println("export function w $main() {")
	//fmt.println("@start")
	//fmt.println("  %a =w add 34, 35")
	//fmt.println("  call $printf(l $fmt, ..., w %r)")
	//fmt.println("  ret 0")
	//fmt.println("}")
	//fmt.println("data $fmt = { b \"%d\\n\", b 0 }")

	//export function w $main() {
	//@start
	//  %r =w call $puts(l $str)
	//  ret 0
	//}
}
