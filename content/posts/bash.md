---
title: Some slightly obscure bash notes.
description: >
  Some slightly obscure bash notes (or things I always forget)
summary: >
  Small collection of bash snippets about things I always forget.
date: 2024-06-29
tags: ["coding", "bash", "shell", "linux"]
author: ["Marco Paganini"]
draft: false
---

# Some Bash notes (or things I always forget)

## Bash arrays

Bash arrays have a weird syntax and are full of caveats (well, it's bash...)

Array initialization:

```bash
declare -a foo

arr=(1 2 3 4)
arr[0]=1
arr[1]=2
arr[1+2]="foo"
```

It's also possible to read the output of a command directly into an array, but
**don't do it**. Look for the `readarray` command below to do avoid common
pitfalls (wildcard and space expansion, etc).

```bash
declare -a foo
foo=$(ls -l)
```

Acccessing members of the array:

```bash
"${foo[@]}"      # Entire array, not IFS separated
"${foo[*]}"      # Entire array, IFS parsed
"${#foo[index]}" # Length of element 'index' in bytes
"${#foo[@]}"     # Number of elements in array
```

* Notes:
  * Braces are **mandatory** when accessing arrays.
  * Negative subscripts mean from the end of the array (-1 == last)

Appending to array:

```bash
arr+=('element')
```

To read stdin into an array safely:

```bash
declare -a foo
readarray foo < <(ls -l)
```

It's possible to use `readarray` to quickly parse a list separated by spaces or
anything else:

```bash
$ a="a b c d e"
$ echo "${a}"
a b c d e
$ readarray -d ' ' foo <<< "${a}"
$ declare -p foo
declare -a foo=([0]="a " [1]="b " [2]="c " [3]="d " [4]=$'e\n')
```

Bash also has associative arrays:

```bash
declare -A assoc
assoc["string"]="another string"
```

or

```bash
declare -A assoc=(
  [foo]=1
  [bar]=2
)
```

Besides the usual ways to reference elements, it's also possible to use
`${!name[@]}` and `${!name[*]}` to expand the indices in the associative array.

To pass an associative array as a function argument, use a reference:

```
function foo() {
  local -n xref="${1}"
  ...
}
declare -A x
...
# Note: No dollar sign.
foo x
```

Deleting elements:

```bash
unset arr            # removes the entire array
unset arr[subscript] # remove one element from the array
```

## Bash regexp examples

```bash
[[ $a =~ \[(.+)\] ]] && echo "yeah ${BASH_REMATCH[0]}"
```

* Neither the value to match nor the regexp are quoted.
* [] need to be quoted if matched literally.
* grouping () and one-or-more (+) don't need quoting.

## Command-line substitution

* First argument of last command: `!!:^`
* nth argument of last command: `!!:n`
* Last argument of last command: `!!:$`
* All arguments of last command: `!!:*`
* Repeat command starting with 'cmd': `!cmd`
* Repeat command containing 'cmd: `!?cmd`
* Sed like substitution: `!!:s/ls -l/cat/` (`!!:gs` for sed's /g modifier)
* `!^cmd^`
* `!cmd:p`

Source:
* http://www.thegeekstuff.com/2011/08/bash-history-expansion

## ISO dates in bash

```bash
$ date '+%Y-%m-%d %H:%M:%S'
```

## Running commands in parallel (with control)

Example using `xargs`:

```bash
echo -e "foo.com\nbar.com\nexample.com" | xargs -I ARG -P 6 curl --silent -q http://ARG/ -o /tmp/ARG.html
```

This won't work when quotes are present in the input. For those cases, escape
the quotes with `%q` in bash's printf:

```bash
cat /tmp/file_with_lines_to_be_quoted | while read -r str; do
  printf "%q\n" "echo The argument value is: ${str}"
done | xargs -I ARG -P 6 /bin/bash -c ARG
```

Note that `xargs` will apparently add implicit single quotes around ARG, so
plan accordingly. Quoting issues can get complicated here.

Another example, using find:

```bash
find . -print0 | xargs -0 -I{} -P 50 bash -c '{ echo "Sleeping for[{}]"; sleep 1; echo "$$"; }'
```

Notes:

* xargs always interprets the command as an executable, so `bash -c` is needed for bash commands.
* Don't forget to finish the {} construct with a semicolon.
* The -L option in xargs is incompatible with -P, but -L 1 is assumed if we use -I {}
* Output is line buffered if sending to stdout, as always. Otherwise, sending to a separate file is a better idea.
