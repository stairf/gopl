#!/usr/bin/env perl

#   getopt.pl - command line options parser generator
#	COPYRIGHT (C) 2013 Stefan Reif -- reif_stefan@web.de
#
#	This program is free software: you can redistribute it and/or modify
#	it under the terms of the GNU General Public License as published by
#	the Free Software Foundation, either version 3 of the License, or
#	(at your option) any later version.
#
#	This program is distributed in the hope that it will be useful,
#	but WITHOUT ANY WARRANTY; without even the implied warranty of
#	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#	GNU General Public License for more details.
#
#	You should have received a copy of the GNU General Public License
#	along with this program.  If not, see <http://www.gnu.org/licenses/>.

our @options;
our %config;
our %help;
our %version;
our @args = ( { name => "arguments", count => "*" } );
#default language
our %lang = (
	help_usage => "usage: %s [options] ",
	help_desc => "DESCRIPTION:",
	help_options => "OPTIONS:",
	help_info => "INFO:",
	opt_unknown => "unknown option `%s'",
	opt_no_val => "the option `%s' needs a value",
	opt_bad_val => "invalid value %s `%s'",
);

my $iguard = "";
my $prefix = "opt";
my $any_help_option;
my $any_version_option;
my $any_long_option;


sub usage {
	print "usage: getopt.pl [OPTIONS] config\n";
	print "options:\n";
	print "\t-c FILE\tprint .c output to FILE\n";
	print "\t-h FILE\tprint .h output to FILE\n";
}

my %opts;
use Getopt::Std;
getopts("h:c:",\%opts);
usage, exit 1 unless ($ARGV[0]);

sub cstring {
	my ($in) = @_;
	$in =~ s/\\/\\\\/g;
	$in =~ s/"/\\"/g;
	$in =~ s/\n/\\n/g;
	$in =~ s/\t/\\t/g;
	$in =~ s/\r/\\r/g;
	$in =~ s/\v/\\v/g;
	$in =~ s/\f/\\f/g;
	return '"' . $in . '"';
} # sub cstring

# declare a C variable
sub declare_var {
	my ($out, $ctype, $varname, $val, $modifiers, $hasvar) = @_;
	return unless $ctype;
	$modifiers .= " " if ($modifiers);
	$varname =~ s/-/_/g;
	print $out $modifiers . "int ${prefix}_has_$varname = 0;\n" if ($hasvar);
	print $out $modifiers . "$ctype ${prefix}_$varname";
	print $out " = $val" if ($val);
	print $out ";\n\n";
} # sub declare_var

#declare the C "get" function
sub declare_get_func {
	my ($out, $ctype, $varname, $modifiers) = @_;
	$varname =~ s/-/_/g;
	$modifiers .= " " if ($modifiers);
	print $out $modifiers . "$ctype ${prefix}_get_$varname (void);\n\n";
} # sub declare_get_func

#declare the C "has" function
sub declare_has_func {
	my ($out, $varname, $modifiers) = @_;
	$varname =~ s/-/_/g;
	$modifiers .= " " if ($modifiers);
	print $out $modifiers . "int ${prefix}_has_$varname (void);\n\n";
} # sub declare_has_func

#print the C "get" function
sub print_get_func {
	my ($out, $ctype, $opt, $modifiers, $name) = @_;
	return unless $ctype;
	$opt =~ s/-/_/g;
	$modifiers .= " " if ($modifiers);
	print $out $modifiers . "$ctype ${prefix}_get_$opt (void) {\n\treturn ${prefix}_$name;\n}\n\n";
} # sub print_get_func

# print the C "has" function
sub print_has_func {
	my ($out, $opt, $modifiers, $name) = @_;
	$opt =~ s/-/_/g;
	$modifiers .= " " if ($modifiers);
	print $out $modifiers . "int ${prefix}_has_$opt (void) {\n\treturn ${prefix}_has_$name;\n}\n\n";
} # sub print_has_func

# print assignment for type "string"
sub string_print_assign {
	my ($out, $indent, $option, $varname, $ref, $src) = @_;
	print $out $indent . "$varname = $src;\n";
} # sub string_print_assign

# print assignment for type "int" and "lint"
sub int_print_assign {
	my ($out, $indent, $option, $varname, $ref, $src) = @_;
	print $out $indent . "char *assign_endptr;\n";
	print $out $indent . "errno = 0;\n";
	print $out $indent . "long assign_l = strtol($src, &assign_endptr, 10);\n";
	print $out $indent . "if ((!*($src)) || errno || *assign_endptr)\n";
	print $out $indent . "\tdie_invalid_value($option, $src);\n";
	print $out $indent . "$varname = assign_l;\n";
} # sub int_print_assign

# print assignment for type "char"
sub char_print_assign {
	my ($out, $indent, $option, $varname, $ref, $src) = @_;
	print $out $indent . "if (($src)[0] == '\\0' || ($src)[1] != '\\0')\n";
	print $out $indent . "\tdie_invalid_value($option, $src);\n";
	print $out $indent . "$varname = ($src)[0];\n";
} # sub char_print_assign

# print assignment for type "counter"
sub counter_print_assign {
	my ($out, $indent, $option, $varname, $ref) = @_;
	print $out $indent . "$varname++;\n";
} # sub counter_print_assign

# print assignment for type "flag"
sub flag_print_assign {
	my ($out, $indent, $option, $varname, $ref) = @_;
	print $out $indent . "$varname = 1;\n";
} # sub flag_print_assign

# print assignment for type "help" --> call help function
sub help_print_assign {
	# this is the "assignment" for a help option
	my ($out, $indent, $option, $varname, $ref) = @_;
	print $out $indent . "do_help(0);\n";
} # sub help_print_assign

sub version_print_assign {
	my ($out, $indent, $option, $varname, $ref) = @_;
	print $out $indent . "do_version();\n";
}

# print assignment for type "callback"
sub callback_print_assign {
	my ($out, $indent, $option, $varname, $ref, $src) = @_;
	my $callback = $ref->{'callback'};
	print $out $indent . "if(!($callback ($src)))\n";
	print $out $indent . "\tdie_invalid_value($option, $src);\n"
} # sub callback_print_assign

# print the C exit call for the "exit" property
sub print_exit_call {
	my ($out, $indent, $exitcode) = @_;
	my $arg = $exitcode;
	$arg = "EXIT_SUCCESS" if ($exitcode eq "SUCCESS");
	$arg = "EXIT_FAILURE" if ($exitcode eq "FAILURE");
	print $out $indent . "exit($arg);\n";
} # print_exit_call

# print the C verify call for the "verify" property
sub print_verify {
	my ($out, $indent, $option, $varname, $src, $verify) = @_;
	print $out $indent . "if (!($verify($varname)))\n";
	print $out $indent . "\tdie_invalid_value($option, $src);\n";
} # sub print_verify

# define option types
my $types = {
	"string" => {
		"ctype" => "const char*",
		"needs_val" => "required",
		"generate_has" => 1, #true
		"generate_get" => 1, #true
		"print_assign" => sub { string_print_assign(@_) },
		"may_verify" => 1,
	},
	"int" => {
		"ctype" => "int",
		"needs_val" => "required",
		"generate_has" => 1, #true
		"generate_get" => 1, #true
		"print_assign" => sub { int_print_assign(@_) },
		"may_verify" => 1,
	},
	"lint" => {
		"ctype" => "long",
		"needs_val" => "required",
		"generate_has" => 1, #true
		"generate_get" => 1, #true
		"print_assign" => sub { int_print_assign(@_) },
		"may_verify" => 1,
	},
	"char" => {
		"ctype" => "char",
		"needs_val" => "required",
		"generate_has" => 1, #true
		"generate_get" => 1, #true
		"print_assign" => sub { char_print_assign(@_) },
		"may_verify" => 1,
	},
	"flag" => {
		"ctype" => "int",
		"needs_val" => 0, #false
		"generate_has" => 0, #true
		"generate_get" => 1, #true
		"print_assign" => sub { flag_print_assign(@_) },
		"may_verify" => 0,
	},
	"counter" => {
		"ctype" => "int",
		"needs_val" => 0, #false
		"generate_has" => 0, #false
		"generate_get" => 1, #true
		"print_assign" => sub { counter_print_assign(@_) },
		"may_verify" => 0,
	},
	"help" => {
		"needs_val" => 0, # TODO: topic --> "optional"
		"generate_has" => 0,
		"generate_get" => 0,
		"print_assign" => sub { help_print_assign(@_) },
		"may_verify" => 0,
	},
	"version" => {
		"needs_val" => 0,
		"generate_has" => 0,
		"generate_get" => 0,
		"print_assign" => sub { version_print_assign(@_) },
		"may_verify" => 0,
	},
	"callback" => {
		"needs_val" => "required",
		"generate_has" => 0,
		"generate_get" => 0,
		"print_assign" => sub { callback_print_assign(@_) },
		"may_verify" => 0,
	}
};

# verify the options and the config
sub verify_options {
	my %short;
	my %long;
	foreach my $option (@options) {
		die "short option '-$option->{short}' not unique\n" if exists($short{$option->{'short'}});
		die "long option '--$option->{long}' not unique\n" if exists($long{$option->{'long'}});
		$short{$option->{'short'}} = 1;
		$long{$option->{'long'}} = 1;
		die "option ". %{$option} ." has no name\n" unless (defined $option->{'short'} or defined $option->{'long'});
		die "option ". %{$option} ." has no type\n" unless (defined $option->{'type'});
		die "option ". %{$option} ." has an unknown type: $option->{type}\n" unless (defined $types->{$option->{'type'}});
		die "invalid short name " . $option->{'short'} unless (($option->{'short'} // "a") =~ /^[a-zA-Z]$/);
		die "invalid long name " . $option->{'long'} unless (($option->{'long'} // "ab") =~ /^[a-zA-Z][a-zA-Z0-9-]+$/);
		die "the type $option->{type} must not have a verify function\n" unless (!$option->{'verify'} or $types->{$option->{type}}->{'may_verify'});
		die "the type $option->{type} must not have a callback function\n" unless (!$option->{'callback'} or $option->{'type'} eq "callback");
		die "the type $option->{type} must have a callback function\n" if (!$option->{'callback'} and $option->{'type'} eq "callback");
		$option->{'name'} = $option->{'short'};
		$option->{'name'} //= $option->{'long'};
		$option->{'name'} =~ s/-/_/g;
		$option->{'name'} .= "_option";
		$any_help_option = 1 if ($option->{'type'} eq "help");
		$any_version_option = 1 if ($option->{'type'} eq "version");
		$any_long_option = 1 if (defined $option->{'long'});
	}
	$prefix = $config{'prefix'} if defined $config{'prefix'};
	$iguard = $config{'iguard'} if defined $config{'iguard'};
} # sub verify_options

sub print_header {
	my ($outfile) = @_;
	open my $out,">$outfile" or die "$outfile: $!\n";
	print $out "/*\n * $outfile\n * getopt.pl generated this header file\n */\n\n";
	print $out "#ifndef $iguard\n#define $iguard\n\n" if ($iguard);

	print $out "extern void ${prefix}_parse(int argc, const char **argv);\n\n";
	print $out "extern int ${prefix}_arg_count(void);\n";
	print $out "extern const char *${prefix}_arg_get(int);\n\n";
	for my $option (@options) {
		my $typename = $option->{'type'};
		my $type = $types->{$typename};
		declare_has_func($out, $option->{'short'}, "extern") if ($type->{'generate_has'} and defined $option->{'short'});
		declare_has_func($out, $option->{'long'}, "extern") if ($type->{'generate_has'} and defined $option->{'long'});
		declare_get_func($out, $type->{'ctype'}, $option->{'short'}, "extern") if ($type->{'generate_get'} and defined $option->{'short'});
		declare_get_func($out, $type->{'ctype'}, $option->{'long'}, "extern") if ($type->{'generate_get'} and defined $option->{'long'});
	}

	print $out "#endif /* $iguard */\n" if ($iguard);
	close $out;
} # sub print_header

sub get_args_min_count {
	my %min = ( '*' => 0, '+' => '1', '?' => '0', '1' => '1' );
	my $sum = 0;
	for my $arg (@args) {
		$sum += $min{$arg->{'count'}};
	}
	return $sum;
}

sub get_args_max_count {
	my %max = ( '?' => 1, '1' => 1 );
	my $sum = 0;
	for my $arg (@args) {
		my $tmp = $max{$arg->{'count'}};
		return undef unless (defined $tmp);
		$sum += $tmp;
	}
	return $sum;
}

sub get_argument_decoration {
	my ($cnt) = @_;
	return ("[","...]") if ($cnt eq "*");
	return ("","...") if ($cnt eq "+");
	return ("[","]") if ($cnt eq "?");
	return ("","");
}

# print the do_help function
sub print_do_help_function {
	my ($out) = @_;
	my $stream = $help{'output'} // "stdout";
	my $indent = $help{'indent'} // " " x2;
	my $indent2 = $help{'indent2'} // " " x4;
	print $out "PRIVATE void do_help(int die_usage) {\n";
	print $out qq @\tfprintf($stream, @ . cstring($lang{help_usage}) . qq @, @ . ($config{'progname'} // "save_argv[0]").qq@);\n@;
	for my $arg (@args) {
		my ($pre,$suf) = get_argument_decoration($arg->{'count'});
		print $out qq @\tfprintf($stream, "%s", "$pre" @ . cstring($arg->{'name'}) . qq @ "$suf " );\n@;
	}
	print $out qq @\tfprintf($stream,"\\n\\n");\n@;
	print $out qq @\tif (die_usage) exit(EXIT_FAILURE);\n@;
	if ($help{'description'}) {
		print $out qq @\tfputs(@ . cstring($lang{help_desc}) . qq @ "\\n", $stream);\n@;
		for my $token (split "\n", $help{'description'}) {
			print $out qq @\tfputs("$indent"  @ .  cstring($token) . qq @  "\\n", $stream);\n@;
		}
		print $out qq @\tfputs("\\n", $stream);\n@;
	}
	if ($help{'show_options'} ne "no") {
		print $out qq @\tfputs(@ . cstring($lang{help_options}) . qq @ "\\n", $stream);\n@;
		for my $o (@options) {
			my $type = $types->{$o->{'type'}};
			print $out qq @\tfputs("$indent@;
			print $out qq @-$o->{short}@ if $o->{'short'};
			print $out qq @ @ if ($o->{'short'} and $o->{'long'});
			print $out qq @--$o->{long}@ if $o->{'long'};
			print $out qq @ " @ . (cstring($o->{'arg'} // "ARG")) . qq @ "@ if ($type->{'needs_val'} eq "required");
			print $out qq @ " "("@ . (cstring($o->{'arg'} // "ARG")) . qq @ ")" "@ if ($type->{'needs_val'} eq "optional");
			print $out qq @\\n$indent2"  @ . cstring($o->{description}) . qq @ "@if $o->{'description'};
			print $out qq @\\n", $stream);\n@;
		}
		print $out qq @\tfputs("\\n", $stream);\n@;
	}
	if ($help{'info'}) {
		print $out qq @\tfputs(@ . cstring($lang{help_info}) . qq @ "\\n", $stream);\n@;
		for my $token (split "\n", $help{'info'}) {
			print $out qq @\tfputs("$indent"  @ . cstring($token) . qq @  "\\n", $stream);\n@;
		}
		print $out qq @\tfputs("\\n", $stream);\n@;
	}
	print $out qq @}\n\n@;
} # sub print_do_help_function

sub print_do_version_function {
	my ($out) = @_;
	my $progname = $config{'progname'} // "save_argv[0]";
	my $stream = $version{'output'} // "stdout";
	my $indent = $version{'indent'} // " " x2;
	print $out "PRIVATE void do_version(void) {\n";
	print $out qq @\tfprintf($stream, "%s %s\\n", $progname, $version{version});\n@ if ($version{'version'});
	print $out qq @\tfputs(@ . cstring($version{copyright}) . qq @  "\\n", $stream);\n@ if ($version{'copyright'});
	print $out qq @\tfputs("\\n", $stream);\n@ if $version{'info'};
	for my $token (split "\n", $version{'info'}) {
		print $out qq @\tfputs("$indent"  @ . cstring($token) . qq @  "\\n", $stream);\n@ if ($version{'info'});
	}
	print $out qq @\tfputs("\\n", $stream);\n@;
	print $out "}\n\n";
} # sub print_do_version_function

sub print_impl {
	my ($outfile) = @_;
	open my $out,">$outfile" or die "$outfile: $!\n";
	print $out "/*\n * generated by getopt.pl\n * DO NOT MODIFY THIS FILE: edit the getopt.pl config instead.\n */\n";
	print $out "#include <stdio.h>\n";
	print $out "#include <stdlib.h>\n";
	print $out "#include <string.h>\n";
	print $out "#include <errno.h>\n";
	print $out "#include $_\n" for (@{$config{'include'}});
	# __attrubute__((unused)) to avoid `unused ...' compiler warnings
	print $out "\n#define PRIVATE static inline __attribute__((unused))\n";
	print $out "#define STR(x) #x\n";
	print $out "\n";
	print $out "static const char **save_argv;\nstatic int save_argc;\n";
	print $out "static int first_arg;\n\n";

	# print the do_help,do_version function
	print_do_help_function($out) if ($any_help_option || get_args_min_count() != 0 || defined get_args_max_count);
	print_do_version_function($out) if ($any_version_option);

	for my $option (@options) {
		my $typename = $option->{'type'};
		my $type = $types->{$typename};
		declare_var ($out, $type->{'ctype'}, $option->{'name'}, $option->{'init'}, "static", $type->{'generate_has'});
		print_get_func($out, $type->{'ctype'}, $option->{'short'}, "", $option->{'name'}) if ($type->{'generate_get'} and $option->{'short'});
		print_get_func($out, $type->{'ctype'}, $option->{'long'}, "", $option->{'name'}) if ($type->{'generate_get'} and $option->{'long'});
		print_has_func($out, $option->{'short'}, "", $option->{'name'}) if ($option->{'short'} and $type->{'generate_has'});
		print_has_func($out, $option->{'long'}, "", $option->{'name'}) if ($option->{'long'} and $type->{'generate_has'});
		print $out "\n";
	}

	print $out "\n";
	print $out "int ${prefix}_arg_count(void) {\n\treturn save_argc - first_arg;\n}\n\n";

	print $out "const char *${prefix}_arg_get(int index) {";
	print $out "\n\tif (index < 0 || first_arg + index > save_argc)\n\t\treturn NULL;" if $config{'indexcheck'};
	print $out "\n\treturn save_argv[first_arg + index];\n";
	print $out "}\n\n";

	print $out qq @PRIVATE void warn_unknown_long(const char *option) {\n@;
	print $out qq @\tfprintf(stderr, @ . cstring($lang{opt_unknown}).qq @ "\\n", option);\n@;
	print $out "\texit(EXIT_FAILURE);\n" if ($config{'unknown'} ne "ignore");
	print $out "}\n\n";

	print $out qq @PRIVATE void warn_unknown_short(const char option) {\n@;
	print $out qq @\tchar opt[3] = {'-', option, '\\0'};\n@;
	print $out qq @\tfprintf(stderr, @ . cstring($lang{opt_unknown}) . qq @ "\\n", opt);\n@;
	print $out "\texit(EXIT_FAILURE);\n" if ($config{'unknown'} ne "ignore");
	print $out "}\n\n";

	print $out qq @PRIVATE void die_noValue_long(const char *option) {\n@;
	print $out qq @\tfprintf(stderr, @ . cstring($lang{opt_no_val}) . qq @ "\\n", option);\n@;
	print $out "\texit(EXIT_FAILURE);\n";
	print $out "}\n\n";

	print $out qq @PRIVATE void die_noValue_short(const char option) {\n@;
	print $out qq @\tchar opt[3] = {'-', option, '\\0'};\n@;
	print $out qq @\tfprintf(stderr, @ . cstring($lang{opt_no_val}) . qq @ "\\n", opt);\n@;
	print $out "\texit(EXIT_FAILURE);\n";
	print $out "}\n\n";

	print $out "PRIVATE int streq(const char *a, const char *b) {\n\treturn !strcmp(a,b);\n";
	print $out "}\n\n";

	print $out "PRIVATE const char *strstart(const char *string, const char *start) {\n";
	print $out "\tsize_t length = strlen(start);\n";
	print $out "\tif (!strncmp(string, start, length))\n\t\treturn string + length;\n";
	print $out "\treturn NULL;\n";
	print $out "}\n\n";

	print $out qq @PRIVATE void die_invalid_value(const char *option, const char *value) {\n@;
	print $out qq @\tfprintf(stderr, @ . cstring($lang{opt_bad_val}) . qq @ "\\n", option, value);\n@;
	print $out "\texit(EXIT_FAILURE);\n";
	print $out "}\n\n";

	# print opt_parse / ${prefix}_parse
	print $out "void ${prefix}_parse(int argc, const char **argv) {\n";
	print $out "\tsave_argv = argv;\n\tsave_argc = argc;\n";
	print $out "\tconst char *a;\n" if ($any_long_option);
	print $out "\tfor (int i = 1; i < argc; ++i) {\n";

	# argv[i] is argument? ->break
	print $out "\t\tif (argv[i][0] != '-' || streq(argv[i], \"-\")) {\n";
	print $out "\t\t\tfirst_arg = i;\n";
	print $out "\t\t\tgoto check_args;\n";
	print $out "\t\t}\n";
	print $out "\t\tif (streq(argv[i], \"--\")) {\n";
	print $out "\t\t\tfirst_arg = i + 1;\n";
	print $out "\t\t\tgoto check_args;\n";
	print $out "\t\t}\n";

	#search long options
	for my $o (grep { defined $_->{'long'} } @options) {
		my $type = $types->{$o->{'type'}};
		my $assign_func = $type->{'print_assign'};
		my $name = $o->{'name'};
		if ($type->{'needs_val'}) {
			# --option=value
			print $out "\t\ta = strstart(argv[i], \"--$o->{'long'}=\");\n";
			print $out "\t\tif (a) {\n";
			print $out "\t\t\t${prefix}_has_$name = 1;\n" if ($type->{'generate_has'});
			&$assign_func($out, "\t\t\t", "\"--$o->{long}\"", "${prefix}_$name", $o, "a");
			print_verify($out, "\t\t\t", "\"--$o->{long}\"", "${prefix}_$name", "a", $o->{'verify'}) if $o->{'verify'};
			print_exit_call($out, "\t\t\t", $o->{'exit'}) if $o->{'exit'};
			print $out "\t\t\tcontinue;\n\t\t}\n";

			# --option value
			print $out "\t\tif (streq(argv[i], \"--$o->{'long'}\")) {\n";
			print $out "\t\t\ti++;\n";
			print $out "\t\t\tif (i == argc)\n\t\t\t\tdie_noValue_long(\"--$o->{long}\");\n" if ($type->{'needs_val'} eq "required");
			print $out "\t\t\t${prefix}_has_$name = 1;\n" if ($type->{'generate_has'});
			&$assign_func($out, "\t\t\t", "\"--$o->{long}\"", "${prefix}_$name", $o, "argv[i]");
			print_verify($out, "\t\t\t", "\"--$o->{long}\"", "${prefix}_$name", "argv[i]", $o->{'verify'}) if $o->{'verify'};
			print_exit_call($out, "\t\t\t", $o->{'exit'}) if $o->{'exit'};
			print $out "\t\t\tcontinue;\n\t\t}\n";

		} else {
			# --flag
			print $out "\t\tif (streq(argv[i], \"--$o->{'long'}\")) {\n";
			print $out "\t\t${prefix}_has_$name = 1;\n" if ($type->{'generate_has'});
			&$assign_func($out, "\t\t\t", "\"--$o->{long}\"", "${prefix}_$name", $o);
			print_exit_call($out, "\t\t\t", $o->{'exit'}) if $o->{'exit'};
			print $out "\t\t\tcontinue;\n\t\t}\n";
		}
	}
	print $out "\t\tif (argv[i][0] == '-' && argv[i][1] == '-') {\n";
	print $out "\t\t\twarn_unknown_long(argv[i]);\n\t\t\tcontinue;\n";
	print $out "\t\t}\n";
	# search short options
	print $out "\t\t/* argv[i][0] == '-' && argv[i][1] != '-' */\n";
	print $out "\t\tfor (int j = 1; argv[i][j]; ++j) {\n";
	for my $o (grep { defined $_->{'short'} } @options) {
		my $type = $types->{$o->{'type'}};
		my $name = $o->{'name'};
		my $assign_func = $type->{'print_assign'};
		print $out "\t\t\tif (argv[i][j] == '$o->{short}') {\n";
		if ($type->{'needs_val'}) {
			# -ovalue
			print $out "\t\t\t\tif (argv[i][j+1]) {\n";
			print $out "\t\t\t\t\t${prefix}_has_$name = 1;\n" if ($type->{'generate_has'});
			&$assign_func($out, "\t\t\t\t\t","\"-$o->{short}\"", "${prefix}_$name", $o, "(argv[i] + j + 1)");
			print_verify($out, "\t\t\t\t\t", "\"-$o->{short}\"", "${prefix}_$name", "(argv[i] + j + 1)", $o->{'verify'}) if $o->{'verify'};
			print_exit_call($out, "\t\t\t\t\t", $o->{'exit'}) if $o->{'exit'};
			print $out "\t\t\t\t\tbreak;\n";
			print $out "\t\t\t\t} else {\n\t\t\t\t\ti++;\n";
			# -o value
			print $out "\t\t\t\t\tif (!argv[i])\n\t\t\t\t\t\tdie_noValue_short('$o->{short}');\n" if ($type->{'needs_val'} eq "required");
			print $out "\t\t\t\t\t${prefix}_has_$name = 1;\n" if ($type->{'generate_has'});
			&$assign_func($out, "\t\t\t\t\t", "\"-$o->{short}\"", "${prefix}_$name", $o, "argv[i]");
			print_verify($out, "\t\t\t\t\t", "\"-$o->{short}\"", "${prefix}_$name", "argv[i]", $o->{'verify'}) if $o->{'verify'};
			print_exit_call($out, "\t\t\t\t\t", $o->{'exit'}) if $o->{'exit'};
			print $out "\t\t\t\t\tbreak;\n\t\t\t\t}\n";
		} else {
			# -f (flag)
			print $out "\t\t\t\t${prefix}_has_$name = 1;\n" if ($type->{'generate_has'});
			&$assign_func($out, "\t\t\t\t", "\"-$o->{short}\"", "${prefix}_" . $o->{'name'});
			print_exit_call($out, "\t\t\t\t", $o->{'exit'}) if $o->{'exit'};
		}
		print $out "\t\t\t\tcontinue;\n";
		print $out "\t\t\t}\n";
	}
	print $out "\t\t\twarn_unknown_short(argv[i][j]);\n";
	print $out "\t\t} /* for (j) */\n";
	print $out "\t} /* for (i) */\n";
	print $out "\tfirst_arg = argc;\n";

	print $out "check_args:\n";
	my $minargs = get_args_min_count();
	my $maxargs = get_args_max_count();
	print $out "\tif (${prefix}_arg_count() < $minargs) do_help(1);\n" if ($minargs != 0);
	print $out "\tif (${prefix}_arg_count() > $maxargs) do_help(1);\n" if (defined $maxargs);
	print $out "\treturn;\n";

	print $out "} /* end of: ${prefix}_parse */\n\n";
	close $out;
} # sub print_impl

### MAIN ###
do $_ for @ARGV;
verify_options;
print_header($opts{h}) if ($opts{h});
print_impl($opts{c}) if ($opts{c});

