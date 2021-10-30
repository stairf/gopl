getopt.pl (GOPL)
================

![make-ci](https://github.com/stairf/gopl/actions/workflows/make-ci.yml/badge.svg)

GOPL is a simple but powerful command-line argument parser generator for C
programs.

Contents
--------

0. [Contents](#contents)
1. [About GOPL](#about-gopl)
2. [Advantages of GOPL](#advantages-of-gopl)
3. [GOPL usage](#gopl-usage)


About GOPL
----------

GOPL is a parser generator. It creates C code, which extracts information from
the `argv` vector passed to the `main()` function at program invocation.

The resulting parser is tailored to the application's command line interface.
The entire interface is defined statically. GOPL needs no runtime support,
except for the libc. The code only uses standard library functions like
`printf` or `memcpy`.

GOPL provides the complete command line interface of the application. Very
little code is required to invoke the GOPL parser and to access option values.

The command line interface is compatible to the GNU standard, which is widely
supported. The generator supports standard options like `--help` and
`--version`.  As far as possible, GOPL generates and formats user information
texts.


Advantages of GOPL
------------------

The GOPL command line parser generator provides some advantages:

 - The High-level configuration is simple to implement, and leads to very little
   code redundancy.
 - The command-line parser provides very flexible input verification, built-in
   type conversion, and consistent internal error handling.
 - Static configuration enables compiler optimization.
 - The generated code is entirely type-safe and verification of input data
   consistency is simple.
 - Many code errors, for instance references to non-existing options, are
   detected at compile-time, instead of run-time.
 - The generated parser provides a very simple interface and is thread-safe.


GOPL usage
----------

The following command reads the configuration file `config.go.pl` and creates the
`options.[ch]` files, which contain the command line parser. Additionally, the
options.d file declares the dependencies of the GOPL build process as required
by `make`.

```sh
$ ./getopt.pl -c options.c -h options.h -d options.d config.go.pl
```

The file [CONFIGURATION.txt](./CONFIGURATION.txt) describes GOPL configuration
files. These files specify the command line interface in detail.

The GOPL script is intended to remain in the project folder. You should *not*
update it regularly because the interfaces might change.


