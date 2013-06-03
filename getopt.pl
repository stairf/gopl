#!/usr/bin/env perl

our @options;
our %config;
our $hdrname = "options.h";
our $iguard = "__IGUARD__";

sub declare_var {
	my ($ctype, $varname,$val,$modifiers,$hasvar) = @_;
	print "$modifiers int opt_has_$varname = 0;\n" if ($hasvar);
	print "$modifiers $ctype opt_$varname";
	print " = $val" if ($val);
	print ";\n\n";
}

sub declare_get_func {
	my ($ctype, $varname,$modifiers) = @_;
	print "$modifiers $ctype opt_get_$varname (void);\n\n";
}

sub declare_has_func {
	my ($varname,$modifiers) = @_;
	print "$modifiers int opt_has_$varname (void);\n\n";
}

sub print_get_func {
	my ($ctype, $opt, $modifiers, $name) = @_;
	print "$modifiers $ctype opt_get_$opt (void) {\n\treturn opt_$name;\n}\n";
}

sub print_has_func {
	my ($opt, $modifiers, $name) = @_;
	print "$modifiers int opt_has_$opt (void) {\n\treturn opt_has_$name;\n}\n";
}

sub string_print_assign {
	my ($indent,$varname, $src) = @_;
	print $indent . "$varname = $src;\n";
}

sub int_print_assign {
	my ($indent,$varname, $src) = @_;
	print $indent . "$varname = atoi($src);\n";
}

sub counter_print_assign {
	my ($indent, $varname) = @_;
	print $indent . "$varname++;\n";
}

sub flag_print_assign {
	my ($indent, $varname) = @_;
	print $indent . "$varname = 1;\n";
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
	print "/*\n * $hdrname\n */\n\n" if $hdrname;
	print "#ifndef $iguard\n#define $iguard\n\n" if ($iguard);

	print "extern void opt_parse(int argc, char **argv);\n\n";
	print "extern int opt_arg_count(void);\n";
	print "extern const char *opt_arg_get(int);\n\n";
	for my $option (@options) {
		my $typename = $option->{'type'};
		my $type = $types->{$typename};
		declare_has_func($option->{'short'}, "extern") if ($type->{'generate_has'} and defined $option->{'short'});
		declare_has_func($option->{'long'}, "extern") if ($type->{'generate_has'} and defined $option->{'long'});
		declare_get_func($type->{'ctype'}, $option->{'short'}, "extern") if ($type->{'generate_get'} and defined $option->{'short'});
		declare_get_func($type->{'ctype'}, $option->{'long'}, "extern") if ($type->{'generate_get'} and defined $option->{'long'});
	}

	print "#endif /* $iguard */\n" if ($iguard);
}

sub print_impl {
	print "#include \"$hdrname\"\n" if $hdrname;
	print "#include $_\n" for (@{$config{'include'}});
	print "\n";
	print "static const char **save_argv;\nstatic int save_argc;\n";
	print "static int first_arg;\n";

	for my $option (@options) {
		my $typename = $option->{'type'};
		my $type = $types->{$typename};
		declare_var ($type->{'ctype'},$option->{'name'},$option->{'init'},"static",$type->{'generate_has'});
		print_get_func($type->{'ctype'},$option->{'short'},"",$option->{'name'}) if $option->{'short'};
		print_get_func($type->{'ctype'},$option->{'long'},"",$option->{'name'}) if $option->{'long'};
		print_has_func($option->{'short'},"",$option->{'name'}) if ($option->{'short'} and $type->{'generate_has'});
		print_has_func($option->{'long'},"",$option->{'name'}) if ($option->{'long'} and $type->{'generate_has'});
		print "\n";
	}

	print "\n";
	print "int opt_arg_count(void) {\n\treturn save_argc - first_arg;\n}\n";
	print "int opt_arg_get(int index) {";
	print "\n\tif(index < 0 || first_arg + index > save_argc)\n\t\treturn NULL;" if $config{'indexcheck'};
	print "\n\treturn save_argv[first_arg + index];\n}\n";
	print "\n";
	print qq @static void warn_unknown_long(const char *option) {\n\tfprintf(stderr, "unknown option \`%s'", option);\n@;
	print "\texit(EXIT_FAILURE);\n" if ($config{'unknown'} eq "die");
	print "}\n";
	print qq @static void warn_unknown_short(const char option) {\n\tfprintf(stderr, "unknown option \`-%c'", option);\n@;
	print "\texit(EXIT_FAILURE);\n" if ($config{'unknown'} eq "die");
	print "}\n";
	print "static int streq(const char *a, const char *b) {\n\treturn !strcmp(a,b);\n}\n";
	print "\n";
	# print opt_parse
	print "void opt_parse(int argc, char **argv) {\n";
	print "\tsave_argv = argv;\n\tconst char *a;\n";
	print "\tfor (int i = 1; i < argc; ++i) {\n";

	# argv[i] is argument? ->break
	print "\t\tif (argv[i][0] != '-') {\n";
	print "\t\t\tfirst_arg = i;\n";
	print "\t\t\treturn;\n";
	print "\t\t}\n";

	#search long options
	for my $o (grep { defined $_->{'long'} } @options) {
		my $type = $types->{$o->{'type'}};
		my $assign_func = $type->{'print_assign'};
		if ($type->{'needs_val'}) {
			print "\t\ta = strstart(argv[i], \"--$o->{'long'}\");\n";
			print "\t\tif (a) {\n";
			&$assign_func("\t\t\t", "opt_" . $o->{'name'}, "a");
			print "\t\t\tcontinue;\n\t\t}\n";
		} else {
			print "\t\tif (streq(argv[i], \"--$o->{'long'}\") {\n";
			&$assign_func("\t\t\t", "opt_" . $o->{'name'});
			print "\t\t\tcontinue;\n\t\t}\n";
		}
	}
	print "\t\tif (argv[i][0] == '-' && argv[i][1] == '-') {\n";
	print "\t\t\twarn_unknwon_long(argv[i]);\n\t\t\tcontinue;\n";
	print "\t\t}\n";
	# search short options
	print "\t\t/* argv[i][0] == '-' && argv[i][1] != '-' */\n";
	print "\t\tfor (int j = 1; argv[i][j]; ++j) {\n";
	for my $o (grep { defined $_->{'short'} } @options) {
		my $type = $types->{$o->{'type'}};
		my $assign_func = $type->{'print_assign'};
		print "\t\t\tif (argv[i][j] == '$o->{short}') {\n";
		if ($type->{'needs_val'}) {
			&$assign_func("\t\t\t\t","opt_" . $o->{'name'}, "argv[i] + j + 1");
			print "\t\t\t\twhile (argv[i][j]) j++;\n";
		} else {
			&$assign_func("\t\t\t\t", "opt_" . $o->{'name'});
		}
		print "\t\t\t\tcontinue;\n";
		print "\t\t\t}\n";
	}
	print "\t\t\twarn_unknown_short(argv[i][j]);\n";
	print "\t\t} /* for (j) */\n";
	print "\t} /* for (i) */\n";
	print "} /* end of: opt_parse */\n";
}

### MAIN ###
do "config.pl";
unify_options;
#print_header;
print_impl;

