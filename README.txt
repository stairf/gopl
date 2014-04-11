getopt.pl readme

=== 0. contents ===
0. contents
1. usage
2. config specification
3. C interface
4. Command line interface
5. Tips and Tricks
6. Quick Start


=== 1. usage ===
use getopt.pl to generate a .c and a .h file that implement your getopt
function. The getopt.pl reads a perl config file which specifies the
command-line options.

The config file should contain:
  - an array @options
  - an array @args
  - a hash %config
  - a hash %help
  - a hash %version
  - a hash %lang
The @options array contains hash references which each declares an option. The
%config hash specifies implementation details. The %help and %version hashes
specify the behaviour of the help and version options.

A short syntax for options is:
@options = (
	{ short => "v", long => "verbose", type => "counter", ... },
	...
);

=== 2. config specification ===
The config file must be a valid perl file. It may define
	- an array @options
	- an array @args
	- a hash %config
	- a hash %help
	- a hash %version
	- a hash %lang

The @option arrays contains hash references. Each of that hash declares an
command-line option.

Those options might have the following keys and values:
	"short"       The value is a single letter. If the value is $X, the option
	              will match the command line argument "-$X".
	"long"        The value contains more that one letter. If the value is $X,
	              the option will match the command line argument "--$X". At
	              least one of "short" and "long" must be specified for each
	              option. Multiple long names can be specified by a
	              comma-separated list.
	"type"        The value is a valid type name. See at type names below for
	              more information. The "type" value is required.
	"arg"         Specify a name for the argument displayed at the help text.
	              The default value is "ARG". The value is ignored if the
	              option (its type) doesn't take an argument.
	"description" Specify a description text for the help text. This is optional.
	"exit"        Exit if this option was specified. This is useful for the help
	              option. Values are "SUCCESS", "FAILURE" for the exit codes
	              EXIT_SUCCESSS and EXIT_FAILURE. If any other value is set,
	              that value will be used as exit code: The value `foo' will
	              create thd C code `exit(foo)'.
	"init"        Initial value for the option. The value is a C expression. The
	              value is statically assigned to the option variable. The value
	              must be quoted for both perl and C, e.g. '"string"';
	"verify"      The value is the name of a function or a macro. The function
	              will be called after the variable assignment. The result of
	              the macro or the function must be an int. If the result is 0,
	              the value is considered to be invalid. The parameter of the
	              function is the (converted) option value. Some option types
	              do not support verify functions.
	"callback"    Name of the callback funcion for the type "callback". The
	              option type must be "callback".
	"values"      Accepted values for enum types. Each enum option must define
	              the value property. The value of this fiels is a
	              comma-separated list of strings.
	"replace"     A list of input replacements. The value must be a hash
	              reference where all keys and all values are strings. When the
	              option argument equals one of the keys, it is replaced by the
	              corresponding hash value.
	"optional"    Optional options do not require a value. The value of this
	              property must be either "yes" or "no". The default is "no".
	              When set to "yes", the option argument is not required. This
	              feature is not supported by options that do not take an
	              argument at all.
	"default"     The default value when the option argument is optional. Some
	              types require that a text is given in the command line. When
	              the option argument is not given, this default text is used.

Available option Types:
Type       Value  C type        Has Get Verify Description
"help"     N?     -             N   N   N      display an auto-generated help text
"version"  N      -             N   N   N      display version information
"int"      Y      int           Y   Y   Y      int argument
"lint"     Y      long int      Y   Y   Y      int argument
"llint"    Y      long long int Y   Y   Y      int argument
"xint"     Y      int           Y   Y   Y      hex int argument
"xlint"    Y      long int      Y   Y   Y      hex int argument
"xllint"   Y      long long int Y   Y   Y      hex int argument
"char"     Y      char          Y   Y   Y      char argument
"string"   (Y)    const char*   Y   Y   Y      string argument
"enum"     Y      int           Y   Y   N      predefined list of accepted values
"float"    Y      float         Y   Y   Y      floating point number
"lfloat"   Y      double        Y   Y   Y      floating point number
"llfloat"  Y      long double   Y   Y   Y      floating point number
"flag"     N      int           N   Y   N      values are true,false
"counter"  N      int           N   Y   N      like flag, but count option arguments
"callback" (Y)    -             N   N   N      value handled by an external function

The type "help" might have an optional value in future versions (help topics).
The callback and the string option both support options without value. Then, a
NULL pointer represents this special case in the C code. All other types
require a default value when the option value is optional.

The args array is similar to the options array. It contains hash references,
where each hash contains one argument specification.

Each args hash might specify the following keys:
	"name"        The name of the argument specification. It is displayed in
	              the help text and the usage text.
	"count"       Values are "1" (exactly one), "?" (at most one), "+" (at
	              least one), and "*" (any number). This fiels specifies how
	              many arguments are covered by this argument specification.
	              When an upper or lower bound exist for the total number of
	              arguments, both constraints are verified by the option
	              parser.
	"description" A description displayed in the help text.

The config hash might specify:
	"progname"      specify the programm name. If not specified, argv[0] is used.
	                The value is a C statement, C strings must be quoted.
	"indexcheck"    add index checks to function calls. Values are "yes" or "no".
	                The default value is "no".
	"include"       The value is an array reference, each entry will be included.
	                The values should look lihe '<systemhdr.h>' or
	                '"localheader.h"'.
	"unknown"       values are "die" (default), "warn" or "ignore". If set to
	                "die", the opt_parse function exits when an unknown option
	                is found. When set to "warn", the option parser prints an
	                error message and continues.  When set to "ignore", the
	                option parser ignores this element in argv.
	"prefix"        The prefix is prepended to every global getopt.pl function.
	                The default value is "opt".
	"iguard"        Include guard for the header file. Default value is "". If
	                the value is empty, no include guard is printed.
	"pagewidth"     The width of the help and usage texts.

The hash %help may contain the keys:
	- output        "stderr" or "stdout"
	- description   a text that describes the programm, optional. This text is
	                displayed after the usage.
	- show_options  "yes" or "no". Default is "yes". Select if options are
	                shown in the help text.
	- show_args     "yes" or "no". Default is "no". Select if arguments are
	                shown in the help text.
	- info          An optional info text. This text is displayed after the
	                options.
	- indent        An indent text. The default are two spaces ("  "). The text
	                should not contain any other characters than spaces.
	- indent2       The second indent text. The text should be longer than the
	                first indent text. The default values are 25 spaces. This
	                text should not contain any other characters than spaces.
	                You can use perl string repetition to simplify the indent
	                strings (e.g. " " x25).

The hash %version my contain the keys:
	- output        "stderr" or "stdout"
	- version       The version string
	- copyright     Copyright information, default is empty
	- info          Additional information
	- indent        indent for the info text, like $help{indent}.

The following entries are quoted automatically:
	- help -> description
	- help -> info
	- options (each) -> arg
	- options (each) -> description
	- version -> copyright
	- version -> info
all other values must be quoted for both perl and C code.

The hash %lang contains all strings that are displayed, e.g. error messages. The
entries are quoted as C strings automatically. Some of them are used in printf
format strings, so they should contains format specifiers.

The hash %lang may define
	- help_usage   the first line of the help text.
	- help_options the line above the options section of the help text
	- opt_unknown  the error message for an unknown option
	- opt_no_val   the error message when an option has no value
	- opt_bad_val  the error message for invalid option values

The values of the %lang hash should contain format specifiers:
	- help_usage   %s (program name)
	- help_options (no format specifier)
	- opt_unknown  %s (name of the unknown option)
	- opt_no_val   %s (name of the option that needs a value)
	- opt_bad_val  %s (option name), %s (invalid value)

=== 3. c interface ===
The generated header declares:
	void opt_parse(int,char**)
	int opt_arg_count(void)
	const char *opt_arg_get(int)

For each option that has a "Has" function:
	int opt_has_X(void)  if the short name of the option is "X"
	int opt_has_XY(void) it the long name of the option is "XY"
If both long and short name are specified, both funtions are generated and
equal. In future versions, one of those functions might be a macro that
expands to the other function.

For each option that has a "Get" function:
	<type> opt_get_X(void)  if the short name of the option is "X"
	<type> opt_get_XY(void) it the long name of the option is "XY"
If both long and short name are specified, the behaviour is the same like the
"Has" functions. <type> is the C type of the option.

The generated c file contains the implementation of those functions.

The opt_parse function parses the option. If any other getopt function is used
before calling opt_parse, the result is undefined. The function has no reeturn
value. It may exit if an error occurred.

The opt_arg_count function takes no argument. The return value is the number
of arguments specified at the command line. The return value may be 0.

The opt_arg_get returns the argument at the specified position. The position
must not be negative and must not be greater than the result of opt_arg_count.

Each "Has" function returns 0 if the option is not found in the command line.
If the option appears, the result is not 0.

Each "Get" function returns the value of the option as it was found in the
command line. If the option is not found, the result is the `init' value of
that option. If no `init' value is specified, the result is undefined.

The character '-' in long names is replaced by '_' in C names.

If $config{'prefix'} is set, this value is used instead of the default "opt"
prefix. In that case the function names do not start with "opt" but with the
value of $config{'prefix'}. This can be used to implement more than one
option parser.

=== 4. Command line interface ===

All options and their values must be the first words of the command line.

Long options that take a value:
	--${LONG}=${value}
	--${LONG} ${value}

Long options that take no value:
	--${LONG}

Short options that that take a value:
	-${SHORT}${value}
	-${SHORT} ${value}

Short options that take no value:
	-${SHORT}

multiple short options can be combined:
	-${SHORT1}${SHORT2}${SHORT3}
	-${SHORT1}${SHORT2}${SHORT3}${value}
	-${SHORT1}${SHORT2}${SHORT3} ${value}
The first options must not take a value. If any short option takes a value, the
rest of the word will be considered to be the option value. In the example
above, ${value} ist the value for ${SHORT3}, but ${SHORT1} and ${SHORT2} take
no value.

When an option value is optional, that text must be in the same element of
argv. When no value is specified in that word in argv, this option is assumed
to be specified without value.

Option parsing stops at the special arguments "--" and "-". If the word "-" is
found, it is taken as the first argument. If the word "--" is found, that word
is ignored and all later words are considered to be arguments.

Long option names can be incomplete, as long as the abbreviation is unique. For
example, the option `--help' can be given using `--h' as long as there is only
one long option name that starts with the character `h'.

=== 5. Tips and Tricks ===
 - The options array should contain the entry
   { short => "h", long => "help", type => "help", exit => "SUCCESS" }
 - If you need complex option types, use the type "callback" and implement
   the callback function, or use type "string" and parse the option string.
 - If you want to read text from a file, use perl backticks and cat:
   { info => "" . `cat version_info.txt` }

=== 6. Quick Start ===

1. Copy the getopt.pl script into your project folder
2. Create an simple configuration file

  ***** start: options.go.pl *****

  @options = (
    { short => "h", long => "help", type => "help", description => "display this help", exit => "SUCCESS" },
	{ long => "version", type => "version", description => "show version information", exit => "SUCCESS" },
  );

  %version = (
    version => cstring("1.0"),
  );

  %config = (
    progname => cstring("myTest"),
  );

  ***** end: options.go.pl *****

3. Run the getopt.pl script to create the command line parser

  $ ./getopt.pl -c options.c -h options.h options.go.pl

4. Create the main function and call the command line parser

  ***** start: main.c *****

  #include "options.h"
  int main(int argc, const char **argv) {
    opt_parse(argc, argv);
	return 0;
  }

  ***** end: main.c *****

5. Compile all code

  $ cc -std=c99 -o myTest main.c options.c

