getopt.pl readme

=== 0. contents ===
0. contents
1. usage
2. config specification
3. C interface
4. command line interface
5. tips and tricks
6. TODO


=== 1. usage ===
use getopt.pl to generate a .c and a .h file that implement your getopt
function. The getopt.pl reads a perl config file which specifies the
command-line options.

=== 2. config specification ===
The config file must be a valid perl file. It may define an array @options and
a hash %config.

The @option arrays contains hash references. Each of that hash declares an
command-line option.

Those options might have the keys and values:
	"short"       the value is a single letter. If the value is $X, the option
	              will match the command line argument "-$X".
	"long"        the value contains more that one letter. If the value is $X,
	              the option will match the command line argument "--$X". At
				  least one of "short" and "long" must be specified for each
				  option.
	"type"        the value is a valid type name. See at type names below for
	              more information. The "type" value is required.
	"arg"         Specify a name for the argument displayed at the help text.
	              The default value is "ARG". The value is ignored it the
				  option (its type) doesn't take an argument.
	"description" Specify a description text for the help text. This is optional.
	"exit"        Exit if this option was specified. This is useful for the help
	              option. Values are "SUCCESS", "FAILURE" for the exit codes
				  EXIT_SUCCESSS and EXIT_FAILURE. If any other value is set,
				  that value will be used as exit code: The value `foo' will
				  create thd C code `exit(foo)'.
	"init"        initial value for the option. The value is a C expression. The
	              value is statically assigned to the option variable.
	"verify"      the value is the name of a function or a macro. The function
	              will be called after the variable assignment. The result of
				  the macro or the function must be an int. If the result is 0,
				  the value is considered to be invalid. The parameter of the
				  function is the (converted) option value. If an option takes
				  no value, the `verify' property is ignored.

available Types:
Type       Value  C type       Has Get Description
"help"     N?     -            N   N   display an auto-generated help text
"int"      Y      int          Y   Y   int argument
"lint"     Y      long int     Y   Y   long int argument
"char"     Y      char         Y   Y   char argument
"string"   Y      const char*  Y   Y   string argument
"flag"     N      int          N   Y   values are true,false
"counter"  N      int          N   Y   like flag, but count option arguments

The type "help" might have an optional value in future versions (help topics).

The config hash might specify:
	"progname"   specify the programm name. If not specified, argv[0] is used.
	             The value is a C statement.
	"indexcheck" add index checks to function calls. Values are "yes" or "no".
	             The default value is "no".
	"include"    The value is an array reference, each entry will be included.
	             The values should look lihe '<systemhdr.h>' or
				 '"localheader.h"'.
	"unknown"    values are "ignore" (default) or "die". If set to "die", the
	             opt_parse function exits when an unknown option is found.
	"prefix"     UNIMPLEMENTED -> namespaces

=== 3. c interface ===
The generated header declares:
	void opt_parse(int,char**)
	int opt_arg_count(void)
	const char *opt_arg_get(int)

For each option that has a "Has" function:
	int opt_has_X(void)  if the short name of the option is "X"
	int opt_has_XY(void) it the long name of the option is "XY"
If both long and short name are specified, both funtions are generated and
equal. It is possible that one of these functions is a preprocessor macro that
redirects to the other function.

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

=== 4. command line interface ===

All options and their values must be the first words of the command line.

long options that take a value:
	--${LONG}=${value}
	--${LONG} ${value}

long options that take no value:
	--${LONG}

short options that that take a value:
	-${SHORT}${value}
	-${SHORT} ${value}

short options that take no value:
	-${SHORT}

multiple short options can be combined:
	-${SHORT1}${SHORT2}${SHORT3}
	-${SHORT1}${SHORT2}${SHORT3}${value}
	-${SHORT1}${SHORT2}${SHORT3} ${value}
the first options must not take a value. If any short option takes a value, the
rest of the word will be considered to be the option value. In the example
above, ${value} ist the value for ${SHORT3}, but ${SHORT1} and ${SHORT2} take
no value.

option parsing stops at the special arguments "--" and "-". If the word "-" is
found, it is taken as the first argument. If the word "--" is found, that word
is ignored and all later words are considered to be arguments.

=== 5. tips and tricks ===

The options array should contain the entry
	{ short => "h", long => "help", type => "help", exit => "SUCCESS" }

=== 6. TODO ===
need moar features:
 - moar data types
 - help topics
 - version option
 - callback type
 - commands
etc
