package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:unicode"

Token :: struct {
	filename: string,
	line:     string,
	word:     string,
	line_nr:  int,
	offset:   int,
}

tokenize_file :: proc(filepath: string) -> [dynamic]Token {
	data, ok := os.read_entire_file(filepath, context.allocator)
	defer delete(data, context.allocator)
	if !ok {
		fmt.println("Could not read file", filepath)
		os.exit(-1)
	}

	tokens: [dynamic]Token
	line_number := 0
	it := string(data)
	for line in strings.split_lines_iterator(&it) {
		line_number += 1
		start := 0
		end := 0

		ch_prev := rune(' ')
		ch_next := rune('.')
		for i in 0 ..< len(line) {
			ch := rune(line[i])
			if i + 1 < len(line) {
				ch_next = rune(line[i + 1])
			} else {
				ch_next = rune(' ')
			}
			if unicode.is_white_space(ch) {
				ch_prev = ch
				continue
			} else {
				if unicode.is_white_space(ch_prev) {
					start = i
				}
				end = i
			}
			if unicode.is_white_space(ch_next) {
				if start <= end {
					append(
						&tokens,
						Token {
							filename = filepath,
							line = strings.clone(line),
							word = strings.clone(line[start:end + 1]),
							line_nr = line_number,
							offset = start,
						},
					)
				}
			}
			ch_prev = ch
		}
	}
	return tokens
}

main :: proc() {
	tokens := tokenize_file("main.prola")
	defer delete(tokens)
	for t in tokens {
		fmt.println(t)
	}
}
