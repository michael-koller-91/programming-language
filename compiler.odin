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
import "core:strings"

build_executable :: proc(file_base: string) {
	cmd1 := fmt.aprintf("qbe %v.qbe -o %v.s", file_base, file_base)
	defer delete(cmd1)
	execute_command(cmd1)

	cmd2 := fmt.aprintf("cc -o %v %v.s", file_base, file_base)
	defer delete(cmd2)
	execute_command(cmd2)
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

run_executable :: proc(file_base: string) -> (string, string, bool) {
	cmd := fmt.aprintf("./%v", file_base)
	defer delete(cmd)
	return execute_command_and_capture_out(cmd)
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
			fmt.fprintln(file_out_handle, "  # -- Expr_Binary (Div)")
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
		os.exit(1)
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
