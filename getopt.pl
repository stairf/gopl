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
	help_args => "ARGUMENTS:",
	help_options => "OPTIONS:",
	opt_unknown => "unknown option `%s'",
	opt_no_val => "the option `%s' needs a value",
	opt_bad_val => "invalid value %s `%s'",
);

my $iguard = "";
my $prefix = "opt";
my $any_help_option;
my $any_version_option;
my $any_short_option = 0;
my @enums;
my %opts;
use Getopt::Std;

# print the usage text
sub usage {
	print "usage: getopt.pl [OPTIONS] config\n";
	print "options:\n";
	print "\t-c FILE\tprint .c output to FILE\n";
	print "\t-h FILE\tprint .h output to FILE\n";
	print "\t-d FILE\tprint .d output to FILE\n";
} # sub usage

# convert a perl string to a perl string containing a C string
sub cstring {
	my ($in) = @_;
	return undef unless defined $in;
	$in =~ s/\\/\\\\/g;
	$in =~ s/"/\\"/g;
	$in =~ s/\n/\\n/g;
	$in =~ s/\t/\\t/g;
	$in =~ s/\r/\\r/g;
	$in =~ s/\v/\\v/g;
	$in =~ s/\f/\\f/g;
	return '"' . $in . '"';
} # sub cstring

# add a file to the dependencies
sub depend {
	my ($file) = @_;
	$INC{$file} = $file if $file;
} # sub depend

# wrap a text
sub wrap {
	my ($prefix, $indent, $text, $pagewidth) = @_;

	my $res = "";
	my $line = $prefix;
	my @paragraphs = split /\n\n/, $text;
	for my $p (@paragraphs) {
		$res .= "\n\n" if $res;
		my @words = split /[ \n\t]+/, $p;
		for my $w (@words) {
			$restlen = $pagewidth - scalar (split //, $line);
			if (scalar (split //, $w) >= $restlen) {
				$res .= $line . "\n";
				$line = $indent;
			} elsif ($line ne $indent and $line ne $prefix) {
				$line .= " ";
			}
			$line .= $w;
		}
		$res .= $line;
		$line = $indent;
	}
	return $res;
} # sub wrap

# print an fputs() statement
sub print_fputs {
	my ($out, $indent, $text, $nl, $stream) = @_;
	print $out "${indent}fputs(" . (join "\n\t$indent", map { cstring("$_\n") } split "\n", $text) . "\n\t$indent" . cstring($nl) . ", $stream);\n";
} # sub print_fputs

# check if a string is contained in an array
sub is_one_of {
	my ($is,@exp) = @_;
	return grep { $is eq $_ } @exp;
} # sub is_one_of

# declare a C variable
sub declare_var {
	my ($out, $ctype, $varname, $val, $modifiers, $hasvar) = @_;
	return unless $ctype;
	$modifiers .= " " if ($modifiers);
	$varname =~ s/-/_/g;
	print $out $modifiers . "bool ${prefix}_has_$varname = false;\n" if ($hasvar);
	print $out $modifiers . "$ctype ${prefix}_$varname";
	print $out " = $val" if ($val);
	print $out ";\n\n";
} # sub declare_var

# print a macro to make one function an alias of another function
sub print_alias {
	my ($out, $fname, $name, $val) = @_;
	print $out "#define ${prefix}_${fname}_$name ${prefix}_${fname}_$val\n\n";
} #sub print_alias


#declare the C "get" function
sub declare_get_func {
	my ($out, $ctype, $varname, $modifiers) = @_;
	$varname =~ s/-/_/g;
	$modifiers .= " " if ($modifiers);
	print $out $modifiers . "$ctype ${prefix}_get_$varname(void);\n\n";
} # sub declare_get_func

#declare the C "has" function
sub declare_has_func {
	my ($out, $varname, $modifiers) = @_;
	$varname =~ s/-/_/g;
	$modifiers .= " " if ($modifiers);
	print $out $modifiers . "bool ${prefix}_has_$varname(void);\n\n";
} # sub declare_has_func

#print the C "get" function
sub print_get_func {
	my ($out, $ctype, $opt, $modifiers, $name) = @_;
	return unless $ctype;
	$opt =~ s/-/_/g;
	$modifiers .= " " if ($modifiers);
	print $out $modifiers . "$ctype ${prefix}_get_$opt(void)\n{\n\treturn ${prefix}_$name;\n}\n\n";
} # sub print_get_func

# print the C "has" function
sub print_has_func {
	my ($out, $opt, $modifiers, $name) = @_;
	$opt =~ s/-/_/g;
	$modifiers .= " " if ($modifiers);
	print $out $modifiers . "bool ${prefix}_has_$opt(void)\n{\n\treturn ${prefix}_has_$name;\n}\n\n";
} # sub print_has_func

# print an enum
sub print_enum {
	my ($out, $long, $short, $values) = @_;
	my @vals = map { s/-/_/gr } split ",", $values;
	my @longnames = split ",", ($long =~ s/-/_/gr);
	my $opt = $short // shift @longnames;
	print $out "enum ${prefix}_value_${opt} {\n";
	print $out map { "\t${prefix}_value_${opt}_$_,\n" } @vals;
	for my $l (@longnames) {
		print $out map { "\t${prefix}_value_${l}_$_ = ${prefix}_value_${opt}_$_,\n" } @vals;
	}
	print $out "};\n\n";
} # sub print_enum

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
	if ($ref->{type} eq "int") {
		print $out $indent . "if ((!*($src)) || errno || *assign_endptr || assign_l < INT_MIN || assign_l > INT_MAX)\n";
	} else {
		print $out $indent . "if ((!*($src)) || errno || *assign_endptr)\n";
	}
	print $out $indent . "\tdie_invalid_value($option, $src);\n";
	print $out $indent . "$varname = assign_l;\n";
} # sub int_print_assign

# print assignment for types "int" and "lint"
sub xint_print_assign {
	my ($out, $indent, $option, $varname, $ref, $src) = @_;
	print $out $indent . "char *assign_endptr;\n";
	print $out $indent . "errno = 0;\n";
	print $out $indent . "long assign_l = strtol($src, &assign_endptr, 16);\n";
	if ($ref->{type} eq "xint") {
		print $out $indent . "if ((!*($src)) || errno || *assign_endptr || assign_l < INT_MIN || assign_l > INT_MAX)\n";
	} else {
		print $out $indent . "if ((!*($src)) || errno || *assign_endptr)\n";
	}
	print $out $indent . "\tdie_invalid_value($option, $src);\n";
	print $out $indent . "$varname = assign_l;\n";
} # sub xint_print_assign

# print assignment for type "llint"
sub llint_print_assign {
	my ($out, $indent, $option, $varname, $ref, $src) = @_;
	print $out $indent . "char *assign_endptr;\n";
	print $out $indent . "errno = 0;\n";
	print $out $indent . "long long assign_l = strtoll($src, &assign_endptr, 10);\n";
	print $out $indent . "if ((!*($src)) || errno || *assign_endptr)\n";
	print $out $indent . "\tdie_invalid_value($option, $src);\n";
	print $out $indent . "$varname = assign_l;\n";
} # sub llint_print_assign

# print assignment for type "llxint"
sub llxint_print_assign {
	my ($out, $indent, $option, $varname, $ref, $src) = @_;
	print $out $indent . "char *assign_endptr;\n";
	print $out $indent . "errno = 0;\n";
	print $out $indent . "long long assign_l = strtoll($src, &assign_endptr, 16);\n";
	print $out $indent . "if ((!*($src)) || errno || *assign_endptr)\n";
	print $out $indent . "\tdie_invalid_value($option, $src);\n";
	print $out $indent . "$varname = assign_l;\n";
} # sub llxint_print_assign

# print assignment for type "float"
sub float_print_assign {
	my ($out, $indent, $option, $varname, $ref, $src) = @_;
	print $out $indent . "char *assign_endptr;\n";
	print $out $indent . "errno = 0;\n";
	print $out $indent . "float assign_f = strtof($src, &assign_endptr);\n";
	print $out $indent . "if ((!*($src)) || errno || *assign_endptr)\n";
	print $out $indent . "\tdie_invalid_value($option, $src);\n";
	print $out $indent . "$varname = assign_f;\n";
} # sub float_print_assign

# print assignment for type "lfloat"
sub lfloat_print_assign {
	my ($out, $indent, $option, $varname, $ref, $src) = @_;
	print $out $indent . "char *assign_endptr;\n";
	print $out $indent . "errno = 0;\n";
	print $out $indent . "double assign_f = strtod($src, &assign_endptr);\n";
	print $out $indent . "if ((!*($src)) || errno || *assign_endptr)\n";
	print $out $indent . "\tdie_invalid_value($option, $src);\n";
	print $out $indent . "$varname = assign_f;\n";
} # sub lfloat_print_assign

# print assignment for type "llfloat"
sub llfloat_print_assign {
	my ($out, $indent, $option, $varname, $ref, $src) = @_;
	print $out $indent . "char *assign_endptr;\n";
	print $out $indent . "errno = 0;\n";
	print $out $indent . "long double assign_f = strtold($src, &assign_endptr);\n";
	print $out $indent . "if ((!*($src)) || errno || *assign_endptr)\n";
	print $out $indent . "\tdie_invalid_value($option, $src);\n";
	print $out $indent . "$varname = assign_f;\n";
} # sub llfloat_print_assign

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

# print assignment for type "version" --> call version function
sub version_print_assign {
	my ($out, $indent, $option, $varname, $ref) = @_;
	print $out $indent . "do_version();\n";
} # sub version_print_assign

# print assignment for type "callback"
sub callback_print_assign {
	my ($out, $indent, $option, $varname, $ref, $src) = @_;
	my $callback = $ref->{callback};
	print $out $indent . "if (!($callback($src)))\n";
	print $out $indent . "\tdie_invalid_value($option, $src);\n"
} # sub callback_print_assign

# print assignment for type "enum"
sub enum_print_assign {
	my ($out, $indent, $option, $varname, $ref, $src) = @_;
	my $name = $ref->{short} // (split ",", $ref->{long})[0] =~ s/-/_/gr;
	my @vals = split ",", $ref->{values};
	print $out $indent;
	print $out join " ", map { "if (streq($src, ". cstring($_) . "))\n$indent\t$varname = ${prefix}_value_${name}_" . (s/-/_/gr) . ";\n${indent}else" } @vals;
	print $out "\n$indent\tdie_invalid_value($option, $src);\n";
} # sub enum_print_assign

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
	string => {
		ctype => "const char*",
		needs_val => "optional",
		generate_has => 1, #true
		generate_get => 1, #true
		print_assign => sub { string_print_assign(@_) },
		may_verify => 1,
	},
	int => {
		ctype => "int",
		needs_val => "required",
		generate_has => 1, #true
		generate_get => 1, #true
		print_assign => sub { int_print_assign(@_) },
		may_verify => 1,
	},
	lint => {
		ctype => "long",
		needs_val => "required",
		generate_has => 1, #true
		generate_get => 1, #true
		print_assign => sub { int_print_assign(@_) },
		may_verify => 1,
	},
	llint => {
		ctype => "long long",
		needs_val => "required",
		generate_has => 1, #true
		generate_get => 1, #true
		print_assign => sub { llint_print_assign(@_) },
		may_verify => 1,
	},
	xint => {
		ctype => "int",
		needs_val => "required",
		generate_has => 1, #true
		generate_get => 1, #true
		print_assign => sub { xint_print_assign(@_) },
		may_verify => 1,
	},
	lxint => {
		ctype => "long",
		needs_val => "required",
		generate_has => 1, #true
		generate_get => 1, #true
		print_assign => sub { xint_print_assign(@_) },
		may_verify => 1,
	},
	llxint => {
		ctype => "long long",
		needs_val => "required",
		generate_has => 1, #true
		generate_get => 1, #true
		print_assign => sub { llxint_print_assign(@_) },
		may_verify => 1,
	},
	float => {
		ctype => "float",
		needs_val => "required",
		generate_has => 1, #true
		generate_get => 1, #true
		print_assign => sub { float_print_assign(@_) },
		may_verify => 1,
	},
	lfloat => {
		ctype => "double",
		needs_val => "required",
		generate_has => 1, #true
		generate_get => 1, #true
		print_assign => sub { lfloat_print_assign(@_) },
		may_verify => 1,
	},
	llfloat => {
		ctype => "long double",
		needs_val => "required",
		generate_has => 1, #true
		generate_get => 1, #true
		print_assign => sub { llfloat_print_assign(@_) },
		may_verify => 1,
	},
	char => {
		ctype => "char",
		needs_val => "required",
		generate_has => 1, #true
		generate_get => 1, #true
		print_assign => sub { char_print_assign(@_) },
		may_verify => 1,
	},
	flag => {
		ctype => "int",
		needs_val => 0, #false
		generate_has => 0, #true
		generate_get => 1, #true
		print_assign => sub { flag_print_assign(@_) },
		may_verify => 0,
	},
	counter => {
		ctype => "int",
		needs_val => 0, #false
		generate_has => 0, #false
		generate_get => 1, #true
		print_assign => sub { counter_print_assign(@_) },
		may_verify => 0,
	},
	help => {
		needs_val => 0, # TODO: topic --> "optional"
		generate_has => 0,
		generate_get => 0,
		print_assign => sub { help_print_assign(@_) },
		may_verify => 0,
	},
	version => {
		needs_val => 0,
		generate_has => 0,
		generate_get => 0,
		print_assign => sub { version_print_assign(@_) },
		may_verify => 0,
	},
	callback => {
		needs_val => "optional",
		generate_has => 0,
		generate_get => 0,
		print_assign => sub { callback_print_assign(@_) },
		may_verify => 0,
	},
	enum => {
		ctype => "int",
		needs_val => "required",
		generate_has => 1,
		generate_get => 1,
		print_assign => sub { enum_print_assign(@_) },
		may_verify => 0,
	},
}; # my $types

# verify the options and the config
sub verify_config {
	my %short;
	my %long;
	my $cnt = 0;
	foreach my $option (@options) {
		die "option #$cnt is no hash reference\n" unless (ref $option eq "HASH");
		die "short option '-$option->{short}' not unique\n" if exists($short{$option->{short}});
		$short{$option->{short}} = 1 if defined $option->{short};
		for (split ",", $option->{long}) {
			die "long option '--$_' not unique\n" if exists($long{$_});
			die "option #$cnt: invalid long name '$_'\n" unless $_ =~ /^[a-zA-Z0-9][a-zA-Z0-9-]+$/;
			$long{$_} = 1;
		}
		die "option #$cnt has no name\n" unless (defined $option->{short} or defined $option->{long});
		die "option #$cnt has no type\n" unless (defined $option->{type});
		die "option #$cnt has an unknown type: $option->{type}\n" unless (defined $types->{$option->{type}});
		die "option #$cnt: invalid short name " . $option->{short} unless (($option->{short} // "a") =~ /^[a-zA-Z0-9]$/);
		die "option #$cnt: the type $option->{type} must not have a verify function\n" unless (!$option->{verify} or $types->{$option->{type}}->{may_verify});
		die "option #$cnt: the type $option->{type} must not have a callback function\n" unless (!$option->{callback} or $option->{type} eq "callback");
		die "option #$cnt: the type $option->{type} must have a callback function\n" if (!$option->{callback} and $option->{type} eq "callback");
		die "option #$cnt: replace must be a hash reference\n" if defined $option->{replace} and ref $option->{replace} ne "HASH";
		$option->{name} = $option->{short} // (split ",", $option->{long})[0] =~ s/-/_/gr;
		$option->{name} .= "_option";
		$any_help_option = 1 if ($option->{type} eq "help");
		$any_version_option = 1 if ($option->{type} eq "version");
		$any_short_option = 1 if defined $option->{short};
		if ($option->{type} eq "enum") {
			push @enums, $option;
			die "option #$cnt: the type 'enum' has no values\n" unless $option->{values};
			die "option #$cnt: invalid value '$_'\n" for grep {!/^[a-zA-Z0-9-]+$/} split ",", $option->{values};
		}
		if ($option->{optional} eq "yes") {
			my $type = $types->{$option->{type}};
			die "option #$cnt takes no value\n" unless $type->{needs_val};
			die "option #$cnt needs a default value\n" unless $type->{needs_val} eq "optional" or defined $option->{default};
		}
		$cnt++;
	}
	$prefix = $config{prefix} if defined $config{prefix};
	$iguard = $config{iguard} if defined $config{iguard};

	for my $arg (@args) {
		die "argument specification #$cnt is no hash reference\n" unless (ref $arg eq "HASH");
		die "argument specification #$cnt has no name\n" unless $arg->{name};
		my $c = $arg->{count};
		die "argument specification #$cnt has invalid count specification: $c\n" unless is_one_of($c,"1","?","*","+");
		$cnt++;
	}

	die "\$config{indexcheck} must be 'yes' or 'no'\n" if (defined $config{indexcheck} and !is_one_of($config{indexcheck},'yes','no'));
	die "\$config{unknown} must be 'die','warn' or 'ignore'\n" if (defined $config{unknown} and !is_one_of($config{unknown},'die','warn','ignore'));
	die "\$config{include} must be an array reference\n" if (defined $config{include} and ref $config{include} ne "ARRAY");

	die "\$help{show_args} must be 'yes' or 'no'\n" if (defined $help{show_args} and !is_one_of($help{show_args},'yes','no'));
	die "\$help{show_options} must be 'yes' or 'no'\n" if (defined $help{show_options} and !is_one_of($help{show_options},'yes','no'));

} # sub verify_config

# generate the header file
sub print_header {
	my ($outfile) = @_;
	open my $out,">$outfile" or die "$outfile: $!\n";
	print $out "/*\n * $outfile\n * getopt.pl generated this header file\n */\n\n";
	print $out "#ifndef $iguard\n#define $iguard\n\n" if ($iguard);
	print $out "#include <stdbool.h>\n";

	print $out "#ifdef __cplusplus\nextern \"C\" {\n#endif /* __cplusplus */\n\n";

	print_enum($out, $_->{long}, $_->{short}, $_->{values}) for @enums;

	print $out "extern void ${prefix}_parse(int argc, const char **argv);\n\n";
	print $out "extern int ${prefix}_arg_count(void);\n";
	print $out "extern const char *${prefix}_arg_get(int);\n\n";
	for my $option (@options) {
		my $typename = $option->{type};
		my $type = $types->{$typename};
		my @longnames = split ",", $option->{long} =~ s/-/_/gr;
		my $name = $option->{short} // shift @longnames;
		if ($type->{generate_has}) {
			declare_has_func($out, $name, "extern");
			print_alias($out, "has", $_, $name) for @longnames;
		}
		if ($type->{generate_get}) {
			declare_get_func($out, $type->{ctype}, $name, "extern");
			print_alias($out, "get", $_, $name) for @longnames;
		}
	}

	print $out "#ifdef __cplusplus\n} /* extern \"C\" */\n#endif /* __cplusplus */\n\n";

	print $out "#endif /* $iguard */\n" if ($iguard);
	close $out;
} # sub print_header

# get the minimum allowed number of arguments
sub get_args_min_count {
	my %min = ( '*' => 0, '+' => 1, '?' => 0, '1' => 1 );
	my $sum = 0;
	for my $arg (@args) {
		$sum += $min{$arg->{count}};
	}
	return $sum;
} # sub get_args_min_count

# get the maximum allowed number of arguments
sub get_args_max_count {
	my %max = ( '?' => 1, '1' => 1 );
	my $sum = 0;
	for my $arg (@args) {
		my $tmp = $max{$arg->{count}};
		return undef unless (defined $tmp);
		$sum += $tmp;
	}
	return $sum;
} # sub get_args_max_count

# get the decoration for arguments in the usage-text
sub decorate_argument {
	my ($cnt,$name) = @_;
	return "[$name...]" if ($cnt eq "*");
	return "$name..." if ($cnt eq "+");
	return "[$name]" if ($cnt eq "?");
	return $name;
} # sub decorate_argument

# read a config file
sub read_config_file {
	my ($config) = @_;
	my $return = do $config;
	die "failed to parse $config: $@\n" if $@;
	die "failed to read $config: $!\n" if $!;
} # sub read_config_file

# print the do_help function
sub print_do_help_function {
	my ($out) = @_;
	my $stream = $help{output} // "stdout";
	my $indent = $help{indent} // " " x2;
	my $indent2 = $help{indent2} // " " x 25;
	my $colwidth = scalar (split //, $indent2);
	my $pagewidth = $config{pagewidth} // 80;
	print $out "PRIVATE void do_help(int die_usage)\n{\n";
	print $out qq @\tfprintf($stream, @ . cstring($lang{help_usage}) . qq @, @ . (cstring($config{progname}) // "save_argv[0]").qq@);\n@;
	my $argdesc = cstring(join " ", map { decorate_argument($_->{count}, $_->{name}) } values @args);
	print $out qq @\tfputs($argdesc, $stream);\n@;
	print $out qq @\tfputs("\\n\\n", $stream);\n@;
	print $out "\tif (die_usage)\n";
	print_exit_call($out,"\t\t",$config{die_status} // "FAILURE");

	print_fputs($out, "\t", wrap("", $indent, $help{description}, $pagewidth), "\n", $stream) if $help{description};
	if ($help{show_args} eq "yes") {
		my $text = $lang{help_args} . "\n";
		for my $a (@args) {

			my $d = sprintf "%-*s ", $colwidth - 1, $indent . $a->{name};
			$d = wrap($d, $indent2, $a->{description}, $pagewidth) if defined $a->{description};
			$text .= "$d\n";
		}
		print_fputs($out, "\t", $text, "\n", $stream) if $text;
	}
	if ($help{show_options} ne "no") {
		my $text = $lang{help_options} . "\n";
		for my $o (@options) {
			my $arg = $o->{arg};
			$arg //= "{" . $o->{values} =~ s/,/|/gr . "}" if $o->{values};
			$arg //= "ARG";
			my $type = $types->{$o->{type}};
			my $d = $indent;
			$d .= "-$o->{short}" if $o->{short};
			$d .= " " if $o->{short} and $o->{long};
			$d .= join " ", map { "--$_" } split ",", $o->{long};
			$d .= " " . $arg if $type->{needs_val} and $o->{optional} ne "yes";
			$d .= "[". ($o->{long} ? "=":"") . $arg . "]" if $o->{optional} eq "yes";
			$d = sprintf "%-*s ", $colwidth - 1, $d if $o->{description};
			$d = wrap($d, $indent2, $o->{description}, $pagewidth) if $o->{description};
			$text .= "$d\n";
		}
		print_fputs($out, "\t", $text, "\n", $stream) if $text;
	}
	print_fputs($out, "\t", wrap("", $indent, $help{info}, $pagewidth), "\n", $stream) if $help{info};
	print $out qq @}\n\n@;
} # sub print_do_help_function

#print the do_version function
sub print_do_version_function {
	my ($out) = @_;
	my $progname = cstring($config{progname}) // "save_argv[0]";
	my $stream = $version{output} // "stdout";
	my $indent = $version{indent} // " " x2;
	print $out "PRIVATE void do_version(void)\n{\n";
	print $out qq @\tfprintf($stream, "%s %s\\n", $progname, $version{version});\n@ if ($version{version});
	print $out qq @\tfputs(@ . cstring($version{copyright}) . qq @  "\\n", $stream);\n@ if ($version{copyright});
	print $out qq @\tfputs("\\n", $stream);\n@;
	print_fputs($out, "\t", wrap("", $indent, $version{info}, $config{pagewidth} // 80), "\n", $stream) if $version{info};
	print $out "}\n\n";
} # sub print_do_version_function

my $trie_cnt = 0;
# insert a value into a trie
sub trie_insert {
	my ($node,$key,$val) = @_;
	# empty node, insert value here
	if (not $node->{entry}->{val} and not defined $node->{children}) {
		$node->{entry} = { key => $key, val => $val };
		return;
	}
	# move down old value
	if (%{ $node->{entry} } and @{ $node->{entry}->{key} }) {
		my $k = shift @{ $node->{entry}->{key} };
		$node->{children}->{$k} //= { id => ++$trie_cnt };
		trie_insert($node->{children}->{$k}, $node->{entry}->{key}, $node->{entry}->{val});
		$node->{entry} = {};
	}
	# insert new value
	if (@{ $key }) {
		my $k = shift @{ $key };
		$node->{children}->{$k} //= { id => ++$trie_cnt };
		trie_insert($node->{children}->{$k}, $key, $val);
	} else {
		$node->{entry} = { key => $key, val => $val };
	}
} # sub trie_insert

# create the options trie
sub trie_create {
	my $root = { id => 0 };
	for my $o (grep { defined $_->{long} } @options) {
		trie_insert($root, [split //, "$_"], $o) for split ",", $o->{long};
	}
	return $root;
} # sub trie_create

# generate trie DFA code
sub trie_code {
	my ($out, $path, $node) = @_;
	my $pathlen = scalar split //, $path;
	print $out "state_$node->{id}:; /* $path */\n";
	print $out "\t". (join "\telse ", map { "if (argv[word_idx][$pathlen] == '$_')\n\t\tgoto state_$node->{children}->{$_}->{id};\n" } sort keys %{ $node->{children} } ) if %{ $node->{children} };
	if (%{ $node->{entry} }) {
		my $o = $node->{entry}->{val};
		print $out "\t/* option: $path" . (join "", @{ $node->{entry}->{key} }) . " */\n";
		if (@{ $node->{entry}->{key} }) {
			print $out "\toption_arg = skip_unique_option_name(argv[word_idx] + $pathlen, \"$path" . (join "", @{ $node->{entry}->{key} }) . "\" + $pathlen);\n";
			print $out "\tif (option_arg == ${prefix}_ERR_PTR)\n\t\tgoto unknown_long;\n";
		} else {
			print $out "\toption_arg = argv[word_idx] + $pathlen;\n";
			print $out "\tif (*option_arg != '\\0' && *option_arg != '=')\n\t\tgoto unknown_long;\n";
			print $out "\tif (*option_arg == '=')\n\t\toption_arg++;\n\telse if (!*option_arg)\n\t\toption_arg = NULL;\n";
		}
		print $out "\toption_name = \"$path" . (join "", @{ $node->{entry}->{key} }) . "\";\n";
		print $out "\tgoto state_assign_$o->{name}_long;\n";
	} else {
		print $out "\tgoto unknown_long;\n";
	}
	trie_code($out, $path . $_, $node->{children}->{$_}) for sort keys %{ $node->{children} };
} # sub trie_code

# generate the c implementation file
sub print_impl {
	my ($outfile) = @_;
	open my $out,">$outfile" or die "$outfile: $!\n";
	print $out "/*\n * generated by getopt.pl\n * DO NOT MODIFY THIS FILE: edit the getopt.pl config instead.\n */\n";
	print $out "#include <stdio.h>\n";
	print $out "#include <stdlib.h>\n";
	print $out "#include <string.h>\n";
	print $out "#include <errno.h>\n";
	print $out "#include <limits.h>\n";
	print $out "#include <stdbool.h>\n";
	print $out "#include $_\n" for (@{$config{include}});
	# __attrubute__((unused)) to avoid `unused ...' compiler warnings
	print $out "\n#ifdef __GNUC__\n#  define PRIVATE static __attribute__((unused))\n#else\n#  define PRIVATE static\n#endif /* __GNUC__ */\n\n";
	print $out "#define STR(x) #x\n";
	print $out "#define ${prefix}_ERR_PTR ((void *)-1)\n";
	print $out "\n";
	print_enum($out, $_->{long}, $_->{short}, $_->{values}) for @enums;
	print $out "static const char **save_argv;\nstatic int save_argc;\n";
	print $out "static int first_arg;\n\n";

	# print the do_help,do_version function
	print_do_help_function($out) if ($any_help_option || get_args_min_count() != 0 || defined get_args_max_count);
	print_do_version_function($out) if ($any_version_option);

	for my $option (@options) {
		my $typename = $option->{type};
		my $type = $types->{$typename};
		my $name = $option->{short} // (split ",", $option->{long})[0] =~ s/-/_/gr;
		declare_var ($out, $type->{ctype}, $option->{name}, $option->{init}, "static", $type->{generate_has});
		print_get_func($out, $type->{ctype}, $name, "", $option->{name}) if $type->{generate_get};
		print_has_func($out, $name, "", $option->{name}) if $type->{generate_has};
		print $out "\n";
	}

	print $out "\n";
	print $out "int ${prefix}_arg_count(void)\n{\n\treturn save_argc - first_arg;\n}\n\n";

	print $out "const char *${prefix}_arg_get(int index)\n{";
	print $out "\n\tif (index < 0 || first_arg + index > save_argc)\n\t\treturn NULL;" if $config{indexcheck};
	print $out "\n\treturn save_argv[first_arg + index];\n";
	print $out "}\n\n";

	print $out "PRIVATE void warn_unknown(const char *option)\n{\n";
	print $out "\tfprintf(stderr, " . cstring($lang{opt_unknown}) . " \"\\n\", option);\n";
	print_exit_call($out, "\t", $config{die_status} // "FAILURE") if ($config{unknown} // "die") eq "die";
	print $out "}\n\n";

	print $out qq @PRIVATE void die_no_value(const char *option)\n{\n@;
	print $out qq @\tfprintf(stderr, @ . cstring($lang{opt_no_val}) . qq @ "\\n", option);\n@;
	print_exit_call($out, "\t", $config{die_status} // "FAILURE");
	print $out "}\n\n";

	print $out "PRIVATE int streq(const char *a, const char *b)\n{\n\treturn !strcmp(a, b);\n";
	print $out "}\n\n";

	print $out qq @PRIVATE void die_invalid_value(const char *option, const char *value)\n{\n@;
	print $out qq @\tfprintf(stderr, @ . cstring($lang{opt_bad_val}) . qq @ "\\n", option, value);\n@;
	print_exit_call($out, "\t", $config{die_status} // "FAILURE");
	print $out "}\n\n";

	print $out "PRIVATE const char *skip_unique_option_name(const char *word, const char *name)\n{\n";
	print $out "\twhile (*name) {\n";
	print $out "\t\tif (*word == '\\0' || *word == '=')\n\t\t\tbreak;\n";
	print $out "\t\tif (*word != *name)\n\t\t\treturn ${prefix}_ERR_PTR;\n";
	print $out "\t\tword++;\n\t\tname++;\n";
	print $out "\t}\n\treturn (*word == '=') ? word + 1 : (*word == '\\0') ? NULL : ${prefix}_ERR_PTR;\n";
	print $out "}\n\n";

	# print opt_parse / ${prefix}_parse
	print $out "void ${prefix}_parse(int argc, const char **argv)\n{\n";
	print $out "\tsave_argv = argv;\n\tsave_argc = argc;\n";
	print $out "\tconst char *option_arg;\n\tconst char *option_name;\n";
	print $out "\tint word_idx = 0;\n\tint char_idx = 0;\n";
	print $out "\tchar short_option_buf[3] = { '-', '\\0', '\\0' };\n";
	print $out "\tconst char *opts[argc];\n\tconst char *args[argc];\n";
	print $out "\tint nargs = 0;\n\tint nopts = 0;\n";
	print $out "\tbool permute = !getenv(\"POSIXLY_CORRECT\");\n";

	print $out "next_word:\n\tword_idx++;\n";
	print $out "\tif (word_idx >= argc)\n\t\tgoto state_check_args;\n";
	print $out "\telse if (argv[word_idx][0] != '-')\n\t\tgoto state_arg;\n";
	print $out "\telse if (argv[word_idx][1] == '\\0')\n\t\tgoto state_arg;\n";
	print $out "\telse if (argv[word_idx][1] != '-')\n\t\tgoto short_name;\n";
	print $out "\telse if (argv[word_idx][1] == '-' && argv[word_idx][2] =='\\0')\n\t\tgoto state_ddash;\n";
	print $out "\topts[nopts++] = argv[word_idx];\n\tgoto state_0;\n";
	print $out "unknown_long:\n";
	print $out "\twarn_unknown(argv[word_idx]);\n" if $config{unknown} ne "ignore";
	print $out "\tgoto next_word;\n";
	# variable assignment states
	for my $o (@options) {
		my $type = $types->{$o->{type}};
		my $assign_func = $type->{print_assign};
		my $name = $o->{name};
		my @longnames = split ",", $o->{long};
		my %replace = %{ $o->{replace} // {} };
		if ($type->{needs_val}) {
			print $out "state_assign_${name}_long:\n" if $o->{long};
			print $out "state_assign_${name}_short:\n" if $o->{short};
			# --option=value, --option value, -ovalue, -o value
			print $out "\t{\n\t\tif (!option_arg) {\n";
			if ($o->{optional} eq "yes") {
				print $out "\t\t\toption_arg = " . ( cstring($o->{default}) // "NULL") . ";\n";
			} else {
				print $out "\t\t\toption_arg = argv[++word_idx];\n";
				print $out "\t\t\tif (!option_arg)\n\t\t\t\tdie_no_value(option_name);\n";
				print $out "\t\t\topts[nopts++] = argv[word_idx];\n";
			}
			print $out "\t\t}\n";

			print $out "\t\t" . (join "\n\t\telse ", map { "if (streq(option_arg, " . cstring($_) . "))\n\t\t\toption_arg = " . cstring($replace{$_}) . ";" } keys %replace) . "\n" if %replace;
			print $out "\t\t${prefix}_has_$name = true;\n" if ($type->{generate_has});
			&$assign_func($out, "\t\t", "option_name", "${prefix}_$name", $o, "option_arg");
			print_verify($out, "\t\t", "option_name", "${prefix}_$name", "option_arg", $o->{verify}) if $o->{verify};
			print_exit_call($out, "\t\t", $o->{exit}) if $o->{exit};
			print $out "\t\tgoto next_word;\n\t}\n";
		} else {
			if ($o->{long}) {
				# --flag, -f
				print $out "state_assign_${name}_long:\n\t{\n";
				print $out "\t\tif (option_arg)\n\t\t\tgoto unknown_long;\n";
				print $out "\t\t${prefix}_has_$name = true;\n" if ($type->{generate_has});
				&$assign_func($out, "\t\t", "\"--$o->{long}\"", "${prefix}_$name", $o);
				print_exit_call($out, "\t\t", $o->{exit}) if $o->{exit};
				print $out "\t\tgoto next_word;\n\t}\n";
			}
			if ($o->{short}) {
				print $out "state_assign_${name}_short:\n\t{\n";
				print $out "\t\t${prefix}_has_$name = true;\n" if ($type->{generate_has});
				&$assign_func($out, "\t\t", "\"--$o->{long}\"", "${prefix}_$name", $o);
				print_exit_call($out, "\t\t", $o->{exit}) if $o->{exit};
				print $out "\t\tgoto next_char;\n\t}\n";
			}
		}
	}

	# long names
	my $trie = trie_create();
	trie_code($out, "--", $trie);

	# short names
	print $out "short_name:\n";
	print $out "\topts[nopts++] = argv[word_idx];\n\tchar_idx = 0;\n";
	print $out "\tgoto next_char;\nnext_char:\n" if $any_short_option;
	print $out "\tchar_idx++;\n";
	print $out "\tif (argv[word_idx][char_idx] == '\\0')\n\t\tgoto next_word;\n";
	print $out "\toption_arg = &argv[word_idx][char_idx+1];\n";
	print $out "\tshort_option_buf[1] = argv[word_idx][char_idx];\n";
	print $out "\toption_name = short_option_buf;\n";
	print $out "\tif (!*option_arg)\n\t\toption_arg = NULL;\n";
	print $out "\t" . (join "\telse ", map { "if (argv[word_idx][char_idx] == '$_->{short}')\n\t\tgoto state_assign_$_->{name}_short;\n" } grep { defined $_->{short} } @options) if $any_short_option;
	print $out "\twarn_unknown(option_name);\n" if $config{unknown} ne "ignore";
	print $out "\tgoto next_word;\n";

	# special arguments: - and --, but every non-option argument is treated like -
	print $out "state_arg:\n";
	print $out "\tif (!permute)\n\t\tgoto state_stop_option_processing;\n";
	print $out "\targs[nargs++] = argv[word_idx];\n";
	print $out "\tgoto next_word;\n";
	print $out "state_ddash:\n\topts[nopts++] = argv[word_idx++];\n\tgoto state_stop_option_processing;\n";
	print $out "state_stop_option_processing:\n\tmemcpy(args + nargs, argv + word_idx, (argc - word_idx) * sizeof(char *));\n\tnargs += argc - word_idx;\n";
	print $out "state_check_args:\n";
	print $out "\tmemcpy(argv + 1, opts, nopts * sizeof(char *));\n";
	print $out "\tmemcpy(argv + 1 + nopts, args, nargs * sizeof(char *));\n";
	print $out "\tfirst_arg = argc - nargs;\n";
	my $minargs = get_args_min_count();
	my $maxargs = get_args_max_count();
	print $out "\tif (nargs < $minargs)\n\t\tdo_help(1);\n" if ($minargs != 0);
	print $out "\tif (nargs > $maxargs)\n\t\tdo_help(1);\n" if (defined $maxargs);
	print $out "\treturn;\n";

	print $out "} /* end of: ${prefix}_parse */\n\n";
	close $out;
} # sub print_impl

# print the deps file
sub print_deps {
	my ($d,$c,$h) = @_;
	open my $out,">$d" or die "$d: $!\n";
	print $out "$c $h $d: " . (join " ", values %INC) . "\n\n";
	close $out;
} # sub print_deps

### MAIN ###
getopts("h:c:d:",\%opts);
usage, exit 1 unless ($ARGV[0]);

read_config_file($_) for @ARGV;
verify_config;
print_header($opts{h}) if ($opts{h});
print_impl($opts{c}) if ($opts{c});
print_deps($opts{d},$opts{c},$opts{h}) if ($opts{d});

