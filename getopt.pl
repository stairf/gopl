#!/usr/bin/env perl

our @options;
our %config;
our $hdrname = "options.h";
our $iguard = "__OPTIONS_H_INCLUDED__";

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
my $any_help_option;

sub declare_var {
	my ($out, $ctype, $varname, $val, $modifiers, $hasvar) = @_;
	return unless $ctype;
	$modifiers .= " " if ($modifiers);
	$varname =~ s/-/_/g;
	print $out $modifiers . "int opt_has_$varname = 0;\n" if ($hasvar);
	print $out $modifiers . "$ctype opt_$varname";
	print $out " = $val" if ($val);
	print $out ";\n\n";
}

sub declare_get_func {
	my ($out, $ctype, $varname, $modifiers) = @_;
	$varname =~ s/-/_/g;
	$modifiers .= " " if ($modifiers);
	print $out $modifiers . "$ctype opt_get_$varname (void);\n\n";
}

sub declare_has_func {
	my ($out, $varname, $modifiers) = @_;
	$varname =~ s/-/_/g;
	$modifiers .= " " if ($modifiers);
	print $out $modifiers . "int opt_has_$varname (void);\n\n";
}

sub print_get_func {
	my ($out, $ctype, $opt, $modifiers, $name) = @_;
	return unless $ctype;
	$opt =~ s/-/_/g;
	$modifiers .= " " if ($modifiers);
	print $out $modifiers . "$ctype opt_get_$opt (void) {\n\treturn opt_$name;\n}\n";
}

sub print_has_func {
	my ($out, $opt, $modifiers, $name) = @_;
	$opt =~ s/-/_/g;
	$modifiers .= " " if ($modifiers);
	print $out $modifiers . "int opt_has_$opt (void) {\n\treturn opt_has_$name;\n}\n";
}

sub string_print_assign {
	my ($out, $indent, $option, $varname, $src) = @_;
	print $out $indent . "$varname = $src;\n";
}

sub int_print_assign {
	my ($out, $indent, $option, $varname, $src) = @_;
	print $out $indent . "errno = 0;\n";
	print $out $indent . "char *assign_endptr;\n";
	print $out $indent . "long assign_l = strtol($src, &assign_endptr, 10);\n";
	print $out $indent . "if ((!*($src)) || errno || *assign_endptr)\n";
	print $out $indent . "\tdie_invalid_value($option,$src);\n";
	print $out $indent . "$varname = assign_l;\n";
}

sub char_print_assign {
	my ($out, $indent, $option, $varname, $src) = @_;
	print $out $indent . "if (($src)[0] == '\\0' || ($src)[1] != '\\0')\n";
	print $out $indent . "\tdie_invalid_value($option,$src);\n";
	print $out $indent . "$varname = ($src)[0];\n";
}

sub counter_print_assign {
	my ($out, $indent, $option, $varname) = @_;
	print $out $indent . "$varname++;\n";
}

sub flag_print_assign {
	my ($out, $indent, $option, $varname) = @_;
	print $out $indent . "$varname = 1;\n";
}

sub help_print_assign {
	# this is the "assignment" for a help option
	my ($out, $indent, $option, $varname) = @_;
	print $out $indent . "do_help();\n";
}


sub print_exit_call {
	my ($out, $indent, $exitcode) = @_;
	my $arg = $exitcode;
	$arg = "EXIT_SUCCESS" if ($exitcode eq "SUCCESS");
	$arg = "EXIT_FAILURE" if ($exitcode eq "FAILURE");
	print $out $indent . "exit($arg);\n";
}

sub print_verify {
	my ($out, $indent, $option, $varname, $src, $verify) = @_;
	print $out $indent . "if (!($verify($varname)))\n";
	print $out $indent . "\tdie_invalid_value($option,$src);\n";
}

my $types = {
	"string" => {
		"ctype" => "const char*",
		"needs_val" => "required",
		"generate_has" => 1, #true
		"generate_get" => 1, #true
		"print_assign" => sub { string_print_assign(@_) }
	},
	"int" => {
		"ctype" => "int",
		"needs_val" => "required",
		"generate_has" => 1, #true
		"generate_get" => 1, #true
		"print_assign" => sub { int_print_assign(@_) }
	},
	"lint" => {
		"ctype" => "long",
		"needs_val" => "required",
		"generate_has" => 1, #true
		"generate_get" => 1, #true
		"print_assign" => sub { int_print_assign(@_) }
	},
	"char" => {
		"ctype" => "char",
		"needs_val" => "required",
		"generate_has" => 1, #true
		"generate_get" => 1, #true
		"print_assign" => sub { char_print_assign(@_) }
	},
	"flag" => {
		"ctype" => "int",
		"needs_val" => 0, #false
		"generate_has" => 0, #true
		"generate_get" => 1, #true
		"print_assign" => sub { flag_print_assign(@_) }
	},
	"counter" => {
		"ctype" => "int",
		"needs_val" => 0, #false
		"generate_has" => 0, #false
		"generate_get" => 1, #true
		"print_assign" => sub { counter_print_assign(@_) }
	},
	"help" => {
		"needs_val" => 0, # TODO: topic --> "optional"
		"generate_has" => 0,
		"generate_get" => 0,
		"print_assign" => sub { help_print_assign(@_) }
	}
};


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
		$option->{'name'} = $option->{'short'} . "_" . $option->{'long'};
		$option->{'name'} =~ s/-/_/g;
		$any_help_option = 1 if ($option->{'type'} eq "help");
	}
}

sub print_header {
	my ($outfile) = @_;
	open my $out,">$outfile" or die "$outfile: $!\n";
	print $out "/*\n * $outfile\n * getopt.pl generated this header file\n */\n\n" if $hdrname;
	print $out "#ifndef $iguard\n#define $iguard\n\n" if ($iguard);

	print $out "extern void opt_parse(int argc, const char **argv);\n\n";
	print $out "extern int opt_arg_count(void);\n";
	print $out "extern const char *opt_arg_get(int);\n\n";
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
}

sub print_impl {
	my ($outfile) = @_;
	open my $out,">$outfile" or die "$outfile: $!\n";
	print $out "/*\n * generated by getopt.pl\n * DO NOT MODIFY THIS FILE: edit the getopt.pl config instead.\n */\n";
	print $out "#include \"$hdrname\"\n" if $hdrname;
	print $out "#include <stdio.h>\n";
	print $out "#include <stdlib.h>\n";
	print $out "#include <string.h>\n";
	print $out "#include <errno.h>\n";
	print $out "#include $_\n" for (@{$config{'include'}});
	# __attrubute__((always_inline)) to avoid `unused ...' compiler warnings
	print $out "\n#define PRIVATE static inline __attribute__((always_inline))\n";
	print $out "\n";
	print $out "static const char **save_argv;\nstatic int save_argc;\n";
	print $out "static int first_arg;\n\n";
	if ($any_help_option) {
		print $out "PRIVATE void do_help(void) {\n";
		print $out qq @\tprintf("usage: %s [options] arguments...\\n\\n", @ . ($config{'progname'} // "save_argv[0]").qq@);\n@;
		# TODO : topics
		print $out qq @\tputs("OPTIONS:");\n@;
		for my $o (@options) {
			my $type = $types->{$o->{'type'}};
			print $out qq @\tputs("\\t@;
			print $out qq @-$o->{short}@ if $o->{'short'};
			print $out qq @ @ if ($o->{'short'} and $o->{'long'});
			print $out qq @--$o->{long}@ if $o->{'long'};
			print $out qq @ @ . ($o->{'arg'} // "ARG") if ($type->{'needs_val'} eq "required");
			print $out qq @ (@ . ($o->{'arg'} // "ARG") . ")" if ($type->{'needs_val'} eq "optional");
			print $out qq @\\n\\t\\t$o->{description}@ if $o->{'description'};
			print $out qq @");\n@;
		}
		print $out qq @}\n@;
	}

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
	print $out "int opt_arg_count(void) {\n\treturn save_argc - first_arg;\n}\n";
	print $out "const char *opt_arg_get(int index) {";
	print $out "\n\tif (index < 0 || first_arg + index > save_argc)\n\t\treturn NULL;" if $config{'indexcheck'};
	print $out "\n\treturn save_argv[first_arg + index];\n}\n";
	print $out "\n";
	print $out qq @PRIVATE void warn_unknown_long(const char *option) {\n\tfprintf(stderr, "unknown option \`%s'\\n", option);\n@;
	print $out "\texit(EXIT_FAILURE);\n" if ($config{'unknown'} eq "die");
	print $out "}\n";
	print $out qq @PRIVATE void warn_unknown_short(const char option) {\n\tfprintf(stderr, "unknown option \`-%c'\\n", option);\n@;
	print $out "\texit(EXIT_FAILURE);\n" if ($config{'unknown'} eq "die");
	print $out "}\n";
	print $out qq @PRIVATE void die_noValue_long(const char *option) {\n\tfprintf(stderr, "the option `%s' needs a value.\\n", option);\n@;
	print $out "\texit(EXIT_FAILURE);\n}\n";
	print $out qq @PRIVATE void die_noValue_short(const char option) {\n\tfprintf(stderr, "the option `-%c' needs a value.\\n", option);\n@;
	print $out "\texit(EXIT_FAILURE);\n}\n";
	print $out "PRIVATE int streq(const char *a, const char *b) {\n\treturn !strcmp(a,b);\n}\n";
	print $out "PRIVATE const char *strstart(const char *string, const char *start) {\n";
	print $out "\tif (!strncmp(string, start, strlen(start)))\n\t\treturn string + strlen(start);\n";
	print $out "\treturn NULL;\n}\n";
	print $out "\n";
	print $out "PRIVATE void die_invalid_value(const char *option, const char *value) {\n";
	print $out "\tfprintf(stderr, \"invalid value %s \`%s'\\n\", option, value);\n";
	print $out "\texit(EXIT_FAILURE);\n";
	print $out "}\n";
	print $out "\n";
	# print opt_parse
	print $out "void opt_parse(int argc, const char **argv) {\n";
	print $out "\tsave_argv = argv;\n\tsave_argc = argc;\n\tconst char *a;\n";
	print $out "\tfor (int i = 1; i < argc; ++i) {\n";

	# argv[i] is argument? ->break
	print $out "\t\tif (argv[i][0] != '-' || streq(argv[i], \"-\")) {\n";
	print $out "\t\t\tfirst_arg = i;\n";
	print $out "\t\t\treturn;\n";
	print $out "\t\t}\n";
	print $out "\t\tif (streq(argv[i], \"--\")) {\n";
	print $out "\t\t\tfirst_arg = i + 1;\n";
	print $out "\t\t\treturn;\n";
	print $out "\t\t}\n";

	#search long options
	for my $o (grep { defined $_->{'long'} } @options) {
		my $type = $types->{$o->{'type'}};
		my $assign_func = $type->{'print_assign'};
		my $name = $o->{'name'};
		if ($type->{'needs_val'}) {
			print $out "\t\ta = strstart(argv[i], \"--$o->{'long'}=\");\n";
			print $out "\t\tif (a) {\n";
			print $out "\t\t\topt_has_$name = 1;\n" if ($type->{'generate_has'});
			&$assign_func($out, "\t\t\t", "\"--$o->{long}\"", "opt_" . $o->{'name'}, "a");
			print_verify($out, "\t\t\t", "\"--$o->{long}\"", "opt_" . $o->{'name'}, "a", $o->{'verify'}) if $o->{'verify'};
			print_exit_call($out, "\t\t\t", $o->{'exit'}) if $o->{'exit'};
			print $out "\t\t\tcontinue;\n\t\t}\n";
			print $out "\t\telse if (streq(argv[i], \"--$o->{'long'}\")) {\n";
			print $out "\t\t\ti++;\n";
			print $out "\t\t\tif (i == argc)\n\t\t\t\tdie_noValue_long(\"--$o->{long}\");\n" if ($type->{'needs_val'} eq "required");
			print $out "\t\t\topt_has_$name = 1;\n" if ($type->{'generate_has'});
			&$assign_func($out, "\t\t\t", "\"--$o->{long}\"", "opt_" . $o->{'name'}, "argv[i]");
			print_verify($out, "\t\t\t", "\"--$o->{long}\"", "opt_" . $o->{'name'}, "argv[i]", $o->{'verify'}) if $o->{'verify'};
			print_exit_call($out, "\t\t\t", $o->{'exit'}) if $o->{'exit'};
			print $out "\t\t\tcontinue;\n\t\t}\n";

		} else {
			print $out "\t\tif (streq(argv[i], \"--$o->{'long'}\")) {\n";
			print $out "\t\topt_has_$name = 1;\n" if ($type->{'generate_has'});
			&$assign_func($out, "\t\t\t", "\"--$o->{long}\"", "opt_" . $o->{'name'});
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
			print $out "\t\t\t\tif (argv[i][j+1]) {\n";
			print $out "\t\t\t\t\topt_has_$name = 1;\n" if ($type->{'generate_has'});
			&$assign_func($out, "\t\t\t\t\t","\"-$o->{short}\"", "opt_" . $o->{'name'}, "(argv[i] + j + 1)");
			print_verify($out, "\t\t\t\t\t", "\"-$o->{short}\"", "opt_" . $o->{'name'}, "(argv[i] + j + 1)", $o->{'verify'}) if $o->{'verify'};
			print_exit_call($out, "\t\t\t\t\t", $o->{'exit'}) if $o->{'exit'};
			print $out "\t\t\t\t\tbreak;\n";
			print $out "\t\t\t\t} else {\n\t\t\t\t\ti++;\n";
			print $out "\t\t\t\t\tif (!argv[i])\n\t\t\t\t\t\tdie_noValue_short('$o->{short}');\n" if ($type->{'needs_val'} eq "required");
			print $out "\t\t\t\t\topt_has_$name = 1;\n" if ($type->{'generate_has'});
			&$assign_func($out, "\t\t\t\t\t", "\"-$o->{short}\"", "opt_" . $o->{'name'}, "argv[i]");
			print_verify($out, "\t\t\t\t\t", "\"-$o->{short}\"", "opt_" . $o->{'name'}, "argv[i]", $o->{'verify'}) if $o->{'verify'};
			print_exit_call($out, "\t\t\t\t\t", $o->{'exit'}) if $o->{'exit'};
			print $out "\t\t\t\t\tbreak;\n\t\t\t\t}\n";
		} else {
			print $out "\t\t\t\topt_has_$name = 1;\n" if ($type->{'generate_has'});
			&$assign_func($out, "\t\t\t\t", "\"-$o->{short}\"", "opt_" . $o->{'name'});
			print_exit_call($out, "\t\t\t\t", $o->{'exit'}) if $o->{'exit'};
		}
		print $out "\t\t\t\tcontinue;\n";
		print $out "\t\t\t}\n";
	}
	print $out "\t\t\twarn_unknown_short(argv[i][j]);\n";
	print $out "\t\t} /* for (j) */\n";
	print $out "\t} /* for (i) */\n";
	print $out "\tfirst_arg = argc;\n";
	print $out "} /* end of: opt_parse */\n\n";
	close $out;
}

### MAIN ###
do $ARGV[0];
verify_options;
print_header($opts{h}) if ($opts{h});
print_impl($opts{c}) if ($opts{c});

