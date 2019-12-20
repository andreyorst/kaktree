# Contributing
General rules on how to write code for Kaktree project.

## Kakscript
- All kakscript files should go inside `rc` directory.
- If one file depends on another, dependency file must be deeper in the filetree. E.g. in `kakscript-path/module-name` directory:
  ```
  rc/
  ├─ modules/
  │  ├─ extra/
  │  │  └─ feature.kak
  │  └─ dependency.kak # depends on extra/feature.kak
  └─ kaktree.kak # depends on modules/dependency.kak
  ``` 
- The main rule for kakscript is to use full names for Kakoune builtin commands, e.g. `edit` instead of `e`, `define-command` instead of `def`, e.t.c.
- Hidden functions should use double dash notation, e.g. `kaktree--some-function` is a hidden function, `kaktree-some-function` is a public function.
- Same applies to variables: `kaktree__some_variable` is a hidden variable, and `kaktree_some_variable` is public.
- Hidden functions doesn't include docstrings, instead comments briefly annotate what function does. Same goes for variables.
- Chained expansions are preferred. E.g. this is better:
  ```
  define-command -hidden kaktree--command %{ evaluate-commands %sh{
      # code
  }}
  ```
  than this:
  ```
  define-command -hidden kaktree--command %{
      evaluate-commands %sh{
          # code
      }
  }
  ```
  However if the length of the line is more than 100 characters, the second variant is preferred.

## Shell expansions
Everything should follow POSIX standards. No bash extensions should be used.

## Perl
Perl files should provide subroutines for outer use, and not used directly as a script file.
This way we can call only needed procedures from single file and use different files as namespaces.
