#!/usr/bin/env perl

our @options;
our %config;
our $hdrname = "options.h";
our $iguard = "__IGUARD__";

my %opts;
use Getopt::Std;
getopts("h:c:",\%opts);

sub declare_var {
	my ($out, $ctype, $varname,$val,$modifiers,$hasvar) = @_;
	print $out "$modifiers int opt_has_$varname = 0;\n" if ($hasvar);
	print $out "$modifiers $ctype opt_$varname";
	print $out " = $val" if ($val);
	print $out ";\n\n";
}

sub declare_get_func {
	my ($out, $ctype, $varname,$modifiers) = @_;
	print $out "$modifiers $ctype opt_get_$varname (void);\n\n";
}

sub declare_has_func {
	my ($out, $varname,$modifiers) = @_;
	print $out "$modifiers int opt_has_$varname (void);\n\n";
}

sub print_get_func {
	my ($out, $ctype, $opt, $modifiers, $name) = @_;
	print $out "$modifiers $ctype opt_get_$opt (void) {\n\treturn opt_$name;\n}\n";
}

sub print_has_func {
	my ($out, $opt, $modifiers, $name) = @_;
	print $out "$modifiers int opt_has_$opt (void) {\n\treturn opt_has_$name;\n}\n";
}

sub string_print_assign {
	my ($out, $indent,$varname, $src) = @_;
	print $out $indent . "$varname = $src;\n";
}

sub int_print_assign {
	my ($out, $indent,$varname, $src) = @_;
	print $out $indent . "$varname = atoi($src);\n";
}

sub counter_print_assign {
	my ($out, $indent, $varname) = @_;
	print $out $indent . "$varname++;\n";
}

sub flag_print_assign {
	my ($out, $indent, $varname) = @_;
	print $out $indent . "$varname = 1;\n";
}


my $types = {
	"string" => {
		"ctype" => "const char*",
		"needs_val" => 1, # true
		"generate_has" => 1, #true
		"generate_get" => 1, #true
		"print_assign" => sub { string_print_assign(@_) }
	},

	"int" => {
		"ctype" => "int",
		"needs_val" => 1, #true
		"generate_has" => 1, #true
		"generate_get" => 1, #true
		"print_assign" => sub { int_print_assign(@_) }
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
	}
};


sub unify_options {
	foreach my $option (@options) {
		die "option ". %{$option} ." has no name\n" unless (defined $option->{'short'} or defined $option->{'long'});
		die "option ". %{$option} ." has no type\n" unless (defined $option->{'type'});
		die "option ". %{$option} ." has an unknown type: $option->{type}\n" unless (defined $types->{$option->{'type'}});
		$option->{'name'} = $option->{'short'} . "_" . $option->{'long'};
	}
}

sub print_header {
	my ($outfile) = @_;
	open my $out,">$outfile" or die "$outfile: $!\n";
	print $out "/*\n * $hdrname\n */\n\n" if $hdrname;
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
	print $out "#include \"$hdrname\"\n" if $hdrname;
	print $out "#include $_\n" for (@{$config{'include'}});
	print $out "\n";
	print $out "static const char **save_argv;\nstatic int save_argc;\n";
	print $out "static int first_arg;\n";

	for my $option (@options) {
		my $typename = $option->{'type'};
		my $type = $types->{$typename};
		declare_var ($out, $type->{'ctype'},$option->{'name'},$option->{'init'},"static",$type->{'generate_has'});
		print_get_func($out, $type->{'ctype'},$option->{'short'},"",$option->{'name'}) if $option->{'short'};
		print_get_func($out, $type->{'ctype'},$option->{'long'},"",$option->{'name'}) if $option->{'long'};
		print_has_func($out, $option->{'short'},"",$option->{'name'}) if ($option->{'short'} and $type->{'generate_has'});
		print_has_func($out, $option->{'long'},"",$option->{'name'}) if ($option->{'long'} and $type->{'generate_has'});
		print $out "\n";
	}

	print $out "\n";
	print $out "int opt_arg_count(void) {\n\treturn save_argc - first_arg;\n}\n";
	print $out "const char *opt_arg_get(int index) {";
	print $out "\n\tif(index < 0 || first_arg + index > save_argc)\n\t\treturn NULL;" if $config{'indexcheck'};
	print $out "\n\treturn save_argv[first_arg + index];\n}\n";
	print $out "\n";
	print $out qq @static void warn_unknown_long(const char *option) {\n\tfprintf(stderr, "unknown option \`%s'\\n", option);\n@;
	print $out "\texit(EXIT_FAILURE);\n" if ($config{'unknown'} eq "die");
	print $out "}\n";
	print $out qq @static void warn_unknown_short(const char option) {\n\tfprintf(stderr, "unknown option \`-%c'\\n", option);\n@;
	print $out "\texit(EXIT_FAILURE);\n" if ($config{'unknown'} eq "die");
	print $out "}\n";
	##print qq @static void exit_noValueLong(const char *option) {\n\tfprintf(stderr, "the option `%s' needs a value.\\n", option);\n@;
	##print "\texit(EXIT_FAILURE);\n}\n";
	print $out qq @static void exit_noValueShort(const char option) {\n\tfprintf(stderr, "the option `-%c' needs a value.\\n", option);\n@;
	print $out "\texit(EXIT_FAILURE);\n}\n";
	print $out "static int streq(const char *a, const char *b) {\n\treturn !strcmp(a,b);\n}\n";
	print $out "static const char *strstart(const char *string, const char *start) {\n";
	print $out "\tif(!strncmp(string, start, strlen(start)))\n\t\treturn string + strlen(start);";
	print $out "\treturn NULL;\n}\n";
	print $out "\n";
	# print opt_parse
	print $out "void opt_parse(int argc, const char **argv) {\n";
	print $out "\tsave_argv = argv;\n\tconst char *a;\n";
	print $out "\tfor (int i = 1; i < argc; ++i) {\n";

	# argv[i] is argument? ->break
	print $out "\t\tif (argv[i][0] != '-') {\n";
	print $out "\t\t\tfirst_arg = i;\n";
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
			&$assign_func($out, "\t\t\t", "opt_" . $o->{'name'}, "a");
			print $out "\t\t\tcontinue;\n\t\t}\n";
		} else {
			print $out "\t\tif (streq(argv[i], \"--$o->{'long'}\")) {\n";
			print $out "\t\topt_has_$name = 1;\n" if ($type->{'generate_has'});
			&$assign_func($out, "\t\t\t", "opt_" . $o->{'name'});
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
			&$assign_func($out, "\t\t\t\t\t","opt_" . $o->{'name'}, "argv[i] + j + 1");
			print $out "\t\t\t\t\tbreak;\n";
			print $out "\t\t\t\t} else {\n\t\t\t\t\ti++;\n";
			print $out "\t\t\t\t\tif (!argv[i])\n\t\t\t\t\t\texit_noValueShort('$o->{short}');\n";
			print $out "\t\t\t\t\topt_has_$name = 1;\n" if ($type->{'generate_has'});
			&$assign_func($out, "\t\t\t\t\t","opt_" . $o->{'name'}, "argv[i]");
			print $out "\t\t\t\t}\n";
		} else {
			print $out "\t\t\t\topt_has_$name = 1;\n" if ($type->{'generate_has'});
			&$assign_func($out, "\t\t\t\t", "opt_" . $o->{'name'});
		}
		print $out "\t\t\t\tcontinue;\n";
		print $out "\t\t\t}\n";
	}
	print $out "\t\t\twarn_unknown_short(argv[i][j]);\n";
	print $out "\t\t} /* for (j) */\n";
	print $out "\t} /* for (i) */\n";
	print $out "} /* end of: opt_parse */\n";
	close $out;
}

### MAIN ###
do "config.pl";
unify_options;
print_header($opts{h}) if ($opts{h});
print_impl($opts{c}) if ($opts{c});

