package main

import "core:fmt"
import "core:log"
import "core:os"
import "core:os/os2"
import "core:path/filepath"
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
	//Float,
	Name,
	Add,
	//Minus,
	//Mult,
}

Parser :: struct {
	tokens: ^[]Token,
	pos:    int,
}

Expr_Type :: enum {
	Add,
	Call,
	Int,
}

Expr_Add :: struct {
	left:  ^Expr,
	right: ^Expr,
}

Expr_Call :: struct {
	args: ^Expr, // TODO: one argument for now; should be a list though
	name: string,
}

Expr_Int :: struct {
	value: int,
}

Expr :: struct {
	type:  Expr_Type,
	value: Expr_Value,
}

Expr_Value :: union {
	^Expr_Add,
	^Expr_Call,
	^Expr_Int,
}

build_executable :: proc(file_base: string) {
	execute_command(fmt.aprintf("qbe %v.qbe -o %v.s", file_base, file_base))
	execute_command(fmt.aprintf("cc -o %v %v.s", file_base, file_base))
}

run_executable :: proc(file_base: string) {
	execute_command(fmt.aprintf("./%v", file_base))
}

execute_command_and_capture_out :: proc(cmd: string) -> (string, string) {
	state, stdout, stderr, err := os2.process_exec(
		{command = strings.split(cmd, " ")},
		context.allocator,
	)
	if err != nil {
		fmt.eprintfln("Error '%v' while executing command '%v'", err, cmd)
		os.exit(1)
	}
	if state.success {
		fmt.printfln("[INFO] Executing command: %v", cmd)
		fmt.print(string(stdout))
	} else {
		fmt.eprintfln("[ERROR]: Executing command %v failed.", cmd)
		fmt.eprintfln("[ERROR]: stdout:")
		fmt.eprint(string(stdout))
		fmt.eprintfln("[ERROR]: stderr:")
		fmt.eprint(string(stderr))
		fmt.eprintfln("[ERROR]: state:")
		fmt.eprint(state)
		os.exit(1)
	}

	return string(stdout), string(stderr)
}

execute_command :: proc(cmd: string) {
	stdout, stderr := execute_command_and_capture_out(cmd)
	defer delete(stdout)
	defer delete(stderr)
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
		log.info("[INFO] Read file", filepath)
	} else {
		fmt.eprintln("[ERROR] Could not read file", filepath)
		os.exit(-1)
	}

	tokens: [dynamic]Token
	line_number := 0
	it := string(data)
	for line_with_comment in strings.split_lines_iterator(&it) {
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
					kind     = Token_Kind.Add,
				}
				append(&tokens, t)
				start = i + 1
				continue
			// case '-':
			// 	t := Token {
			// 		filename = filepath,
			// 		line     = strings.clone(line_with_comment),
			// 		word     = strings.clone("-"),
			// 		line_nr  = line_number,
			// 		offset   = i,
			// 		kind     = Token_Kind.Minus,
			// 	}
			// 	append(&tokens, t)
			// 	start = i + 1
			// 	continue
			// case '*':
			// 	t := Token {
			// 		filename = filepath,
			// 		line     = strings.clone(line_with_comment),
			// 		word     = strings.clone("*"),
			// 		line_nr  = line_number,
			// 		offset   = i,
			// 		kind     = Token_Kind.Mult,
			// 	}
			// 	append(&tokens, t)
			// 	start = i + 1
			// 	continue
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
							// n, ok := strconv.parse_f64(t.word)
							// if ok {
							// 	t.kind = Token_Kind.Float
							// 	t.value = n
							// } else {
							eprint_loc_and_exit(t, "Could not parse as int.")
							// }
						}
					} else {
						t.kind = Token_Kind.Name
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

// TODO: print Token_Kind in human readable form; maybe a proc token_kind_to_string or something
expect_token :: proc(token: Token, expected_kind: Token_Kind) {
	if token.kind != expected_kind {
		eprint_loc_and_exit(
			token,
			fmt.aprintf("Expected Token_Kind %v but got %v", expected_kind, token.kind),
		)
	}
}

parse_add :: proc(parser: ^Parser) -> ^Expr {
	left := parse_unary(parser)
	if left == nil {return nil}
	if parser.pos < len(parser.tokens) && parser.tokens[parser.pos].kind == Token_Kind.Add {
		parser.pos += 1
		right := parse_add(parser)
		if right == nil {return nil}
		expr_add := new(Expr_Add, context.temp_allocator)
		expr_add.left = left
		expr_add.right = right
		log.info("( pos =", parser.pos - 1, ") return new expr")
		expr := new(Expr, context.temp_allocator)
		expr.type = Expr_Type.Add
		expr.value = expr_add
		return expr
	}
	log.info("( pos =", parser.pos, ") return left")
	return left
}

parse_args :: proc(parser: ^Parser) -> ^Expr {
	t := parser.tokens[parser.pos]
	expect_token(t, Token_Kind.Lpar)
	parser.pos += 1

	expr := parse_expr(parser)

	t = parser.tokens[parser.pos]
	expect_token(t, Token_Kind.Rpar)
	parser.pos += 1

	return expr
}

parse_expr :: proc(parser: ^Parser) -> ^Expr {
	return parse_add(parser)
}

parse_tokens :: proc(tokens: ^[]Token) -> []Expr {
	parser := Parser {
		tokens = tokens,
		pos    = 0,
	}
	expressions: [dynamic]Expr
	for parser.pos < len(parser.tokens) - 1 {
		expr := parse_expr(&parser)
		append(&expressions, expr^)
	}

	log.infof("Finished generating expressions. Generated %v expressions.", len(expressions))
	fmt.println("AST:")
	for &expr in expressions {
		print_tree(&expr, 1)
	}

	return expressions[:]
}

parse_unary :: proc(parser: ^Parser) -> ^Expr {
	if parser.pos >= len(parser.tokens) {
		t := parser.tokens[len(parser.tokens) - 1]
		eprint_loc_and_exit(t, "Expected to find a constant next but found end of file.")
	}
	t := parser.tokens[parser.pos]
	parser.pos += 1
	switch t.kind {
	case Token_Kind.Name:
		expr_call := new(Expr_Call, context.temp_allocator)
		expr_call.name = t.word
		log.info("( pos =", parser.pos - 1, ") call =", t.word)
		expr_call.args = parse_args(parser)
		expr := new(Expr, context.temp_allocator)
		expr.type = Expr_Type.Call
		expr.value = expr_call
		return expr
	case Token_Kind.Int:
		expr_int := new(Expr_Int, context.temp_allocator)
		expr_int.value = t.value.?
		log.info("( pos =", parser.pos - 1, ") int =", t.value)
		expr := new(Expr, context.temp_allocator)
		expr.type = Expr_Type.Int
		expr.value = expr_int
		return expr
	case Token_Kind.Lpar:
		assert(false, "unreachable")
	case Token_Kind.Rpar:
		assert(false, "unreachable")
	case Token_Kind.Add: // nothing to do
	}
	return nil
}

compile_expr :: proc(expr: ^Expr, varnr: int, file_out_handle: os.Handle) -> (int, bool) {
	switch &e in expr.value {
	case ^Expr_Add:
		varnr_l, wrote_l := compile_expr(e.left, varnr, file_out_handle)
		varnr, wrote := compile_expr(e.right, varnr + 1, file_out_handle)
		assert(varnr >= 2, "Expected at least two variables to perform + on.")
		fmt.fprintln(file_out_handle, "  # -- Expr_Add")
		fmt.fprintfln(
			file_out_handle,
			"  %%s%d =l add %%s%d, %%s%d",
			varnr,
			varnr_l - 1,
			varnr - 1,
		)
		log.infof("add %%s%d = %%s%d + %%s%d", varnr, varnr_l - 1, varnr - 1)
		return varnr + 1, true
	case ^Expr_Call:
		if e.name == "print" {
			varnr, wrote := compile_expr(e.args, varnr, file_out_handle)
			fmt.fprintfln(file_out_handle, "  # -- Expr_Call: %v()", e.name)
			fmt.fprintfln(file_out_handle, "  call $printf(l $fmt_int, ..., l %%s%v)", varnr - 1)
			log.infof("call print(): %%s%d", varnr - 1)
			return varnr, false
		} else {
			assert(false, fmt.aprintf("unknown call name: '%v'; not implemented", e.name))
		}
	case ^Expr_Int:
		fmt.fprintfln(file_out_handle, "  # -- Expr_Int: %v", e.value)
		fmt.fprintfln(file_out_handle, "  %%s%d =l copy %d", varnr, e.value)
		log.infof("int %%s%d = %d", varnr, e.value)
		return varnr + 1, true
	}
	assert(false, "unreachable")
	return 0, false
}

print_tree :: proc(expr: ^Expr, depth: int) -> int {
	for i in 0 ..< 2 * depth {fmt.print(" ")}
	d := depth + 1

	switch e in expr^.value {
	case ^Expr_Add:
		fmt.println("Add:")
		print_tree(e^.left, d)
		print_tree(e^.right, d)
		return d - 1
	case ^Expr_Call:
		fmt.printfln("Call: %v()", e^.name)
		print_tree(e^.args, d)
		return d - 1
	case ^Expr_Int:
		fmt.println("Const:", e^.value)
		return d - 1
	}
	return 0
}

main :: proc() {
	context.logger = log.create_console_logger()

	file_in_path := "programs/01_print_sums.prola"
	file_in_stem := filepath.stem(filepath.base(file_in_path))
	dir_out := "build_prola"

	tokens := tokenize_file(file_in_path)
	defer delete_tokens(tokens)

	expressions := parse_tokens(&tokens)
	defer free_all(context.temp_allocator)

	file_out_base := filepath.join({dir_out, file_in_stem})
	file_out_qbe := strings.concatenate({file_out_base, ".qbe"})

	if os.exists(file_out_qbe) {
		err := os.remove(file_out_qbe)
		if err == nil {
			fmt.println("[INFO] Deleted old file", file_out_qbe)
		} else {
			fmt.eprintfln("[ERROR] Failed to remove old %v due to error %v", file_out_qbe, err)
		}
	}

	file_out_handle, err := os.open(file_out_qbe, os.O_CREATE | os.O_WRONLY, 444)
	if err == os.ERROR_NONE {
		fmt.println("[INFO] Opened file", file_out_qbe)
	} else {
		fmt.eprintln("[ERROR] Could not open file", file_out_qbe, ":", err)
		os.exit(-1)
	}
	defer os.close(file_out_handle)

	fmt.fprintln(file_out_handle, "export function w $main() {")
	fmt.fprintln(file_out_handle, "@start")

	varnr := 0
	for &expr in expressions {
		varnr2, wrote := compile_expr(&expr, varnr, file_out_handle)
		varnr = varnr2
	}

	fmt.fprintln(file_out_handle, "  ret 0")
	fmt.fprintln(file_out_handle, "}")
	fmt.fprintln(file_out_handle, "data $fmt_int = { b \"%d\\n\", b 0 }")

	file_out, ok := os.read_entire_file(file_out_qbe, context.allocator)
	defer delete(file_out, context.allocator)

	fmt.printfln("\nContents of %v:\n", file_out_qbe)
	fmt.print(string(file_out))

	build_executable(file_out_base)
	run_executable(file_out_base)
}
