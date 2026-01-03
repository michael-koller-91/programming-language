# Programming Language

This is a recreational programming project to learn how to
* use the programming language Odin.
* use the compiler backend QBE.
* create my own programming language.

The language does not have a name yet.

## Setup

The file [setup.sh](setup/setup.sh) describes how to get Odin and QBE.
After adding both folders to PATH (as is done in [.envrc](.envrc)), running [setup_check.sh](setup/setup_check.sh) should print a Hello, World once from Odin and once from QBE.

## Language Features

### Arithmetics

There is no traditional operator precedence.
Every operator implicitely opens a new set of brackets.
Consequently, the following two lines print different results:
```python
print(2 + 3 * 4) # prints 14 because 14 = 2 + (3 * 4)
print(3 * 4 + 2) # prints 18 because 18 = 3 * (4 + 2)
```

