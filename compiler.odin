// TODO: use ^Token instead of Token in proc arguments
// TODO: handle missing closing parenthesis, e.g., 'print(1+2'; improve missing closing bracket error message
// TODO: make binary expressions left-associative

package main

import "base:runtime"
import "core:fmt"
import "core:log"
import "core:os"
import "core:os/os2"
import "core:path/filepath"
import "core:strconv"
import "core:strings"
import "core:unicode"

Parser :: struct {
	tokens: ^[]Token,
	pos:    int,
}

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
	Comment,
	Lpar, // (
	Rpar, // )
	Int,
	Name,
	Add,
	Div,
	Mul,
	Sub,
}

token_kind_str :: proc(t: Token_Kind) -> string {
	switch t {
	case .Comment:
		return "#"
	case .Lpar:
		return "("
	case .Rpar:
		return ")"
	case .Int:
		return "integer"
	case .Name:
		return "identifier"
	case .Add:
		return "+"
	case .Div:
		return "/"
	case .Mul:
		return "*"
	case .Sub:
		return "-"
	}
	assert(false, "unreachable")
	return ""
}

Expr_Type :: enum {
	Binary,
	Call,
	Int,
}

Expr_Binary_Type :: enum {
	Add,
	Div,
	Mul,
	Sub,
}

Expr_Binary :: struct {
	type:  Expr_Binary_Type,
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
	^Expr_Binary,
	^Expr_Call,
	^Expr_Int,
}

build_executable :: proc(file_base: string) {
	cmd1 := fmt.aprintf("qbe %v.qbe -o %v.s", file_base, file_base)
	defer delete(cmd1)
	execute_command(cmd1)

	cmd2 := fmt.aprintf("cc -o %v %v.s", file_base, file_base)
	defer delete(cmd2)
	execute_command(cmd2)
}

run_executable :: proc(file_base: string) -> (string, string, bool) {
	cmd := fmt.aprintf("./%v", file_base)
	defer delete(cmd)
	return execute_command_and_capture_out(cmd)
}

execute_command_and_capture_out :: proc(cmd: string) -> (string, string, bool) {
	command := strings.split(cmd, " ")
	defer delete(command)

	state, stdout, stderr, err := os2.process_exec({command = command}, context.allocator)

	if err != nil {
		fmt.eprintfln("Error '%v' while executing '%v'", err, cmd)
		os.exit(1)
	}
	if state.success {
		fmt.printfln("[CINFO] Executed: %v", cmd)
	} else {
		fmt.eprintfln("[CERROR]: Executing '%v' failed.", cmd)
		fmt.eprintfln("[CERROR]: stdout:")
		fmt.eprint(string(stdout))
		fmt.eprintfln("[CERROR]: stderr:")
		fmt.eprint(string(stderr))
		fmt.eprintfln("[CERROR]: state:")
		fmt.eprint(state)
		os.exit(1)
	}

	return string(stdout), string(stderr), state.success
}

execute_command :: proc(cmd: string) {
	stdout, stderr, ok := execute_command_and_capture_out(cmd)
	if ok {
		fmt.print(string(stdout))
	}
	defer delete(stdout)
	defer delete(stderr)
}

is_seperator :: proc(r: rune) -> (is_sep: bool) {
	is_sep = false
	seperators := [?]rune{'+', '*', '-', ' ', '\t', '(', ')'}
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
		fmt.println("[CINFO] Read file", filepath)
	} else {
		fmt.eprintln("[CERROR] Could not read file", filepath)
		os.exit(-1)
	}

	tokens: [dynamic]Token
	line_number := 0
	it := string(data)
	for line_with_comment in strings.split_lines_iterator(&it) {
		line_number += 1
		start := 0
		end := 0

		split_lines := strings.split(line_with_comment, "#")
		defer delete(split_lines)
		line := split_lines[0]

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
				// spaces
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
			case '-':
				t := Token {
					filename = filepath,
					line     = strings.clone(line_with_comment),
					word     = strings.clone("-"),
					line_nr  = line_number,
					offset   = i,
					kind     = Token_Kind.Sub,
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
					kind     = Token_Kind.Mul,
				}
				append(&tokens, t)
				start = i + 1
				continue
			case '/':
				t := Token {
					filename = filepath,
					line     = strings.clone(line_with_comment),
					word     = strings.clone("/"),
					line_nr  = line_number,
					offset   = i,
					kind     = Token_Kind.Div,
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
		log.debugf("line %d: %s (%s)", t.line_nr, t.word, t.kind)
	}
	log.debugf("Finished tokenizing %s. Found %d tokens.", filepath, len(tokens))
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
	fmt.eprintfln("%s:%d:%d [CERROR] %s", t.filename, t.line_nr, t.offset + 1, msg)
	os.exit(1)
}

// TODO: print Token_Kind in human readable form; maybe a proc token_kind_to_string or something
expect_token :: proc(token: ^Token, expected_kind: Token_Kind) {
	if token.kind != expected_kind {
		eprint_loc_and_exit(
			token^,
			fmt.aprintf(
				"Expected '%v' but got '%v'",
				token_kind_str(expected_kind),
				token_kind_str(token.kind),
			),
		)
	}
}

consume_token :: proc(parser: ^Parser) -> ^Token {
	token := get_current_token(parser)
	parser.pos += 1
	return token
}

get_current_token :: proc(parser: ^Parser) -> ^Token {
	return &parser.tokens[parser.pos]
}

out_of_tokens :: proc(parser: ^Parser) -> bool {
	return parser.pos >= len(parser.tokens)
}

make_binary_expr :: proc(type: Expr_Binary_Type, left: ^Expr, right: ^Expr) -> ^Expr {
	expr_bin := new(Expr_Binary, context.temp_allocator)
	expr_bin.type = type
	expr_bin.left = left
	expr_bin.right = right
	expr := new(Expr, context.temp_allocator)
	expr.type = Expr_Type.Binary
	expr.value = expr_bin
	log.debugf("Created binary expression of type %v", type)
	return expr
}

parse_binary :: proc(parser: ^Parser, left: ^Expr) -> ^Expr {
	token := consume_token(parser)
	right := parse_expr(parser)
	if token.kind == Token_Kind.Add {
		return make_binary_expr(Expr_Binary_Type.Add, left, right)
	} else if token.kind == Token_Kind.Div {
		return make_binary_expr(Expr_Binary_Type.Div, left, right)
	} else if token.kind == Token_Kind.Mul {
		return make_binary_expr(Expr_Binary_Type.Mul, left, right)
	} else if token.kind == Token_Kind.Sub {
		return make_binary_expr(Expr_Binary_Type.Sub, left, right)
	}

	assert(false, "unreachable")
	return nil
}

parse_expr :: proc(parser: ^Parser) -> (expr: ^Expr) {
	left := parse_unary(parser)

	if out_of_tokens(parser) {
		return left
	}

	token := get_current_token(parser)

	switch token.kind {
	case Token_Kind.Comment:
	case Token_Kind.Name:
		expr = left
	case Token_Kind.Int:
		expr = left
	case Token_Kind.Lpar:
		expr = left
	case Token_Kind.Rpar:
		expr = left
	case Token_Kind.Add:
		expr = parse_binary(parser, left)
	case Token_Kind.Div:
		expr = parse_binary(parser, left)
	case Token_Kind.Mul:
		expr = parse_binary(parser, left)
	case Token_Kind.Sub:
		expr = parse_binary(parser, left)
	}

	return
}

parse_args :: proc(parser: ^Parser) -> ^Expr {
	token := consume_token(parser)
	expect_token(token, Token_Kind.Lpar)

	// TODO: check if next token is Rpar to handle 'print()'?
	expr := parse_expr(parser)

	token = consume_token(parser)
	expect_token(token, Token_Kind.Rpar)

	return expr
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

	log.debugf("Finished parsing tokens. Generated %v expressions.", len(expressions))
	fmt.println("AST:")
	for &expr in expressions {
		print_tree(&expr, 1)
	}

	//for &expr in expressions {
	//	print_code(&expr, 0)
	//}
	//fmt.println()

	return expressions[:]
}

parse_unary :: proc(parser: ^Parser) -> ^Expr {
	if out_of_tokens(parser) {
		t := parser.tokens[len(parser.tokens) - 1]
		eprint_loc_and_exit(t, "Ran out of tokens.") // TODO: How can this be turned into a useful error message?
	}

	token := consume_token(parser)

	switch token.kind {
	case Token_Kind.Comment:
	case Token_Kind.Name:
		expr_call := new(Expr_Call, context.temp_allocator)
		expr_call.name = token.word
		log.debug("( pos =", parser.pos - 1, ") call =", token.word)
		expr_call.args = parse_args(parser)
		expr := new(Expr, context.temp_allocator)
		expr.type = Expr_Type.Call
		expr.value = expr_call
		return expr
	case Token_Kind.Int:
		expr_int := new(Expr_Int, context.temp_allocator)
		expr_int.value = token.value.?
		log.debug("( pos =", parser.pos - 1, ") int =", token.value)
		expr := new(Expr, context.temp_allocator)
		expr.type = Expr_Type.Int
		expr.value = expr_int
		return expr
	case Token_Kind.Lpar:
	case Token_Kind.Rpar:
	case Token_Kind.Add:
	case Token_Kind.Div:
	case Token_Kind.Mul:
	case Token_Kind.Sub:
	}

	eprint_loc_and_exit(token^, "Expected a unary expression.")

	return nil
}

compile_file :: proc(file_in_path: string) -> string {
	dir_out := "build_prola"
	file_in_stem := filepath.stem(filepath.base(file_in_path))

	tokens := tokenize_file(file_in_path)
	defer delete_tokens(tokens)

	expressions := parse_tokens(&tokens)
	defer delete(expressions)
	defer free_all(context.temp_allocator)

	file_out_base := filepath.join({dir_out, file_in_stem})

	compile_to_qbe(file_out_base, &expressions)

	return file_out_base
}

compile_expr :: proc(expr: ^Expr, varnr: int, file_out_handle: os.Handle) -> (int, bool) {
	switch &e in expr.value {
	case ^Expr_Binary:
		varnr_l, wrote_l := compile_expr(e.left, varnr, file_out_handle)
		varnr, wrote := compile_expr(e.right, varnr + 1, file_out_handle)
		assert(varnr >= 2, "Expected at least two variables to perform binary operation on.")
		if e.type == Expr_Binary_Type.Add {
			fmt.fprintln(file_out_handle, "  # -- Expr_Binary (Add)")
			fmt.fprintfln(
				file_out_handle,
				"  %%s%d =l add %%s%d, %%s%d",
				varnr,
				varnr_l - 1,
				varnr - 1,
			)
			log.debugf("add %%s%d = %%s%d + %%s%d", varnr, varnr_l - 1, varnr - 1)
		} else if e.type == Expr_Binary_Type.Div {
			fmt.fprintln(file_out_handle, "  # -- Expr_Binary (Mul)")
			fmt.fprintfln(
				file_out_handle,
				"  %%s%d =l div %%s%d, %%s%d",
				varnr,
				varnr_l - 1,
				varnr - 1,
			)
			log.debugf("mul %%s%d = %%s%d / %%s%d", varnr, varnr_l - 1, varnr - 1)
		} else if e.type == Expr_Binary_Type.Mul {
			fmt.fprintln(file_out_handle, "  # -- Expr_Binary (Mul)")
			fmt.fprintfln(
				file_out_handle,
				"  %%s%d =l mul %%s%d, %%s%d",
				varnr,
				varnr_l - 1,
				varnr - 1,
			)
			log.debugf("mul %%s%d = %%s%d * %%s%d", varnr, varnr_l - 1, varnr - 1)
		} else if e.type == Expr_Binary_Type.Sub {
			fmt.fprintln(file_out_handle, "  # -- Expr_Binary (Sub)")
			fmt.fprintfln(
				file_out_handle,
				"  %%s%d =l sub %%s%d, %%s%d",
				varnr,
				varnr_l - 1,
				varnr - 1,
			)
			log.debugf("add %%s%d = %%s%d - %%s%d", varnr, varnr_l - 1, varnr - 1)
		} else {
			assert(false, "unreachable")
		}
		return varnr + 1, true
	case ^Expr_Call:
		if e.name == "print" {
			varnr, wrote := compile_expr(e.args, varnr, file_out_handle)
			fmt.fprintfln(file_out_handle, "  # -- Expr_Call: %v()", e.name)
			fmt.fprintfln(file_out_handle, "  call $printf(l $fmt_int, ..., l %%s%v)", varnr - 1)
			log.debugf("call print(): %%s%d", varnr - 1)
			return varnr, false
		} else {
			assert(false, fmt.aprintf("unknown call name: '%v'; not implemented", e.name))
		}
	case ^Expr_Int:
		fmt.fprintfln(file_out_handle, "  # -- Expr_Int: %v", e.value)
		fmt.fprintfln(file_out_handle, "  %%s%d =l copy %d", varnr, e.value)
		log.debugf("int %%s%d = %d", varnr, e.value)
		return varnr + 1, true
	}
	assert(false, "unreachable")
	return 0, false
}

compile_to_qbe :: proc(file_out_base: string, expressions: ^[]Expr) {
	file_out_qbe := strings.concatenate({file_out_base, ".qbe"})
	defer delete(file_out_qbe)

	if os.exists(file_out_qbe) {
		err := os.remove(file_out_qbe)
		if err == nil {
			fmt.println("[CINFO] Deleted old file", file_out_qbe)
		} else {
			fmt.eprintfln(
				"[CERROR] Failed to remove old file '%v' due to error '%v'",
				file_out_qbe,
				err,
			)
		}
	}

	file_out_handle, err := os.open(file_out_qbe, os.O_CREATE | os.O_WRONLY, 444)
	if err == os.ERROR_NONE {
		fmt.println("[CINFO] Created file", file_out_qbe)
	} else {
		fmt.eprintln("[CERROR] Could not create file", file_out_qbe, ":", err)
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
}

// potentially a way to format code?
print_code :: proc(expr: ^Expr, depth: int) -> int {
	d := depth + 1

	if depth == 0 {
		fmt.println()
	}

	switch e in expr^.value {
	case ^Expr_Binary:
		print_code(e^.left, d)
		if e.type == Expr_Binary_Type.Add {
			fmt.print(" + ")
		} else if e.type == Expr_Binary_Type.Mul {
			fmt.print(" * ")
		} else if e.type == Expr_Binary_Type.Sub {
			fmt.print(" - ")
		}
		print_code(e^.right, d)
		return d - 1
	case ^Expr_Call:
		fmt.printf("%v(", e^.name)
		print_code(e^.args, d)
		fmt.printf(")")
		return d - 1
	case ^Expr_Int:
		fmt.printf("%v", e^.value)
		return d - 1
	}
	return 0
}

print_tree :: proc(expr: ^Expr, depth: int) -> int {
	for i in 0 ..< 2 * depth {fmt.print(" ")}
	d := depth + 1

	switch e in expr^.value {
	case ^Expr_Binary:
		if e.type == Expr_Binary_Type.Add {
			fmt.println("Add:")
		} else if e.type == Expr_Binary_Type.Div {
			fmt.println("Div:")
		} else if e.type == Expr_Binary_Type.Mul {
			fmt.println("Mul:")
		} else if e.type == Expr_Binary_Type.Sub {
			fmt.println("Sub:")
		} else {
			assert(false, "unreachable")
		}
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

	file_in_path := "programs/01_arithmetics.prola"
	file_out_base := compile_file(file_in_path)
	build_executable(file_out_base)
	stdout, stderr, ok := run_executable(file_out_base)
	fmt.println(stdout)
	defer delete(stdout)
	defer delete(stderr)
}
