package main

import "core:fmt"
import "core:log"
import "core:os"
import "core:strconv"

Parser :: struct {
	tokens: ^[]Token,
	pos:    int,
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

consume_token :: proc(parser: ^Parser) -> ^Token {
	parser.pos += 1
	return &parser.tokens[parser.pos - 1]
}

eprint_loc_and_exit :: proc(t: Token, msg: string) {
	fmt.eprintln(t.line)
	for i in 0 ..< t.loc.column {
		fmt.eprint(" ")
	}
	fmt.eprintln("^")
	fmt.eprintfln("%s:%d:%d [CERROR] %s", t.filename, t.loc.line_nr, t.loc.column + 1, msg)
	os.exit(1)
}

expect_token :: proc(token: ^Token, expected_kind: Token_Kind) {
	if token.kind != expected_kind {
		eprint_loc_and_exit(
			token^,
			fmt.aprintf(
				"Expected '%v' but got '%v'",
				token_kind_str[expected_kind],
				token_kind_str[token.kind],
			),
		)
	}
}

get_current_token :: proc(parser: ^Parser) -> ^Token {
	// skip comments
	for parser.tokens[parser.pos].kind == .Comment {
		consume_token(parser)
	}
	return &parser.tokens[parser.pos]
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

out_of_tokens :: proc(parser: ^Parser) -> bool {
	return peek_token(parser).kind == .EOF
}

peek_token :: proc(parser: ^Parser) -> ^Token {
	token := get_current_token(parser)
	if token.kind == .EOF {
		return token
	} else {
		return &parser.tokens[parser.pos + 1]
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////

parse_args :: proc(parser: ^Parser) -> ^Expr {
	token := consume_token(parser)
	expect_token(token, Token_Kind.L_Par)

	// TODO: check if next token is R_Par to handle 'print()'?
	expr := parse_expr(parser)

	token = consume_token(parser)
	expect_token(token, Token_Kind.R_Par)

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
	case Token_Kind.COUNT:
	case Token_Kind.EOF:
	case Token_Kind.Identifier:
		expr = left
	case Token_Kind.Integer:
		expr = left
	case Token_Kind.L_Par:
		expr = left
	case Token_Kind.R_Par:
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

parse_tokens :: proc(tokens: ^[]Token) -> []Expr {
	parser := Parser {
		tokens = tokens,
		pos    = 0,
	}

	expressions: [dynamic]Expr
	for get_current_token(&parser).kind != .EOF {
		expr := parse_expr(&parser)
		append(&expressions, expr^)
	}

	log.debugf("Finished parsing tokens. Generated %v expressions.", len(expressions))
	fmt.println("AST:")
	for &expr in expressions {
		print_tree(&expr, 1)
	}

	return expressions[:]
}

parse_unary :: proc(parser: ^Parser) -> ^Expr {
	token := consume_token(parser)

	switch token.kind {
	case Token_Kind.Comment:
	case Token_Kind.COUNT:
	case Token_Kind.EOF:
	case Token_Kind.Identifier:
		expr_call := new(Expr_Call, context.temp_allocator)
		expr_call.name = token.word
		log.debug("( pos =", parser.pos - 1, ") call =", token.word)
		expr_call.args = parse_args(parser)
		expr := new(Expr, context.temp_allocator)
		expr.type = Expr_Type.Call
		expr.value = expr_call
		return expr
	case Token_Kind.Integer:
		expr_int := new(Expr_Int, context.temp_allocator)
		expr_int.value, _ = strconv.parse_int(token.word)
		log.debug("( pos =", parser.pos - 1, ") int =", token.word)
		expr := new(Expr, context.temp_allocator)
		expr.type = Expr_Type.Int
		expr.value = expr_int
		return expr
	case Token_Kind.L_Par:
	case Token_Kind.R_Par:
	case Token_Kind.Add:
	case Token_Kind.Div:
	case Token_Kind.Mul:
	case Token_Kind.Sub:
	}

	eprint_loc_and_exit(token^, "Expected a unary expression.")

	return nil
}
