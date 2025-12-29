#!/usr/bin/env python3

import ast


def print_ast(s: str):
    print("input:")
    print(s)
    print("-" * 5)
    print(ast.dump(ast.parse(s), indent=True))
    print("=" * 20)


print_ast("35+34+2")
print_ast("35+34\n4+5")
