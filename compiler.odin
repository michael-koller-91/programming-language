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

Expr_Type :: enum {
	Plus,
	Constant_Int,
}

Expr_Plus :: struct {
	left:  ^Expr,
	right: ^Expr,
}

Expr_Const_Int :: struct {
	value: int,
}

Expr :: struct {
	type:  Expr_Type,
	value: Expr_Value,
}

Expr_Value :: union {
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
	line_loop: for line_with_comment in strings.split_lines_iterator(&it) {
		line_number += 1
		start := 0
		end := 0

		line := strings.split(line_with_comment, "#")[0]

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
					line     = strings.clone(line_with_comment),
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
					line     = strings.clone(line_with_comment),
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
					line     = strings.clone(line_with_comment),
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
					line     = strings.clone(line_with_comment),
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
					line     = strings.clone(line_with_comment),
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
						line     = strings.clone(line_with_comment),
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
								eprint_loc_and_exit(t, "Could not parse as int or float.")
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
	for t in tokens {
		log.infof("line %d: %s (%s)", t.line_nr, t.word, t.kind)
	}
	log.infof("Finished tokenizing %s. Found %d tokens.", filepath, len(tokens))
	return tokens[:]
}

delete_tokens :: proc(tokens: []Token) {
	for t in tokens {
		delete(t.line)
		delete(t.word)
	}
	delete(tokens)
}

eprint_loc_and_exit :: proc(t: Token, msg: string) {
	fmt.eprintln(t.line)
	for i in 0 ..< t.offset {
		fmt.eprint(" ")
	}
	fmt.eprintln("^")
	fmt.eprintfln("%s:%d:%d [ERROR] %s", t.filename, t.line_nr, t.offset + 1, msg)
	os.exit(1)
}

parse_constant :: proc(parser: ^Parser) -> ^Expr {
	if parser.pos >= len(parser.tokens) {
		t := parser.tokens[len(parser.tokens) - 1]
		eprint_loc_and_exit(t, "Expected to find a constant next but found end of file.")
	}
	t := &parser.tokens[parser.pos]
	parser.pos += 1
	expr_const := new(Expr_Const_Int, context.temp_allocator)
	expr_const.value = t.value.?
	log.info("( pos =", parser.pos - 1, ") constant =", t.value)
	expr := new(Expr, context.temp_allocator)
	expr.type = Expr_Type.Constant_Int
	expr.value = expr_const
	return expr
}

parse_plus :: proc(parser: ^Parser) -> ^Expr {
	left := parse_constant(parser)
	if left == nil {return nil}
	if parser.pos < len(parser.tokens) && parser.tokens[parser.pos].kind == Token_Kind.Plus {
		parser.pos += 1
		right := parse_plus(parser)
		if right == nil {return nil}
		expr_plus := new(Expr_Plus, context.temp_allocator)
		expr_plus.left = left
		expr_plus.right = right
		log.info("( pos =", parser.pos - 1, ") return new expr")
		expr := new(Expr, context.temp_allocator)
		expr.type = Expr_Type.Plus
		expr.value = expr_plus
		return expr
	}
	log.info("( pos =", parser.pos, ") return left")
	return left
}

compile_constant :: proc(expr: ^Expr, varnr: int, file_out_handle: os.Handle) -> (int, bool) {
	if expr.type == Expr_Type.Constant_Int {
		const_int := expr.value.(^Expr_Const_Int)
		fmt.fprintfln(file_out_handle, "  # compile_constant: %d", const_int.value)
		fmt.fprintfln(file_out_handle, "  %%s%d =l copy %d", varnr, const_int.value)
		log.info("wrote constant = ", const_int.value)
		return varnr + 1, true
	}
	return varnr, false
}

compile_plus :: proc(expr: ^Expr, varnr: int, file_out_handle: os.Handle) -> (int, bool) {
	if expr.type == Expr_Type.Plus {
		plus := expr.value.(^Expr_Plus)
		varnr, wrote := compile_constant(plus.left, varnr, file_out_handle)
		//if !wrote {return varnr, false}
		varnr, wrote = compile_constant(plus.right, varnr, file_out_handle)
		assert(varnr >= 2, "Expected at least two variables to perform + on.")
		fmt.fprintln(file_out_handle, "  # compile_plus")
		fmt.fprintfln(file_out_handle, "  %%s%d =l add %%s%d, %%s%d", varnr, varnr - 2, varnr - 1)
		return varnr, true
	}
	return varnr, false
}

print_tree :: proc(expr: ^Expr, depth: int) -> int {
	for i in 0 ..< 2 * depth {fmt.print(" ")}
	d := depth + 1

	switch e in expr^.value {
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

	parser := Parser {
		tokens = &tokens,
		pos    = 0,
	}
	expressions: [dynamic]Expr
	for parser.pos < len(parser.tokens) - 1 {
		expr := parse_plus(&parser)
		append(&expressions, expr^)
	}
	defer free_all(context.temp_allocator)

	file_out_path := "foo.qbe"
	file_out_handle, err := os.open(file_out_path, os.O_CREATE | os.O_WRONLY, 444)
	if err == os.ERROR_NONE {
		log.info("Opened file", file_out_path)
	} else {
		fmt.eprintln("[ERROR] Could not open file", file_out_path, ":", err)
		os.exit(-1)
	}
	defer os.close(file_out_handle)

	for &expr in expressions {
		print_tree(&expr, 0)
	}


	//file_out_handle := os.stdout
	fmt.fprintln(file_out_handle, "export function w $main() {")
	fmt.fprintln(file_out_handle, "@start")
	fmt.fprintln(file_out_handle, "# -----------------------------------")


	for &expr in expressions {
		compile_plus(&expr, 0, file_out_handle)
	}

	fmt.fprintln(file_out_handle, "# -----------------------------------")
	fmt.fprintln(file_out_handle, "  call $printf(l $fmt, ..., l %s2)")
	fmt.fprintln(file_out_handle, "  ret 0")
	fmt.fprintln(file_out_handle, "}")
	fmt.fprintln(file_out_handle, "data $fmt = { b \"%d\\n\", b 0 }")

	file_out, ok := os.read_entire_file(file_out_path, context.allocator)
	defer delete(file_out, context.allocator)

	fmt.printfln("\nContents of %v:\n", file_out_path)
	fmt.print(string(file_out))

}
