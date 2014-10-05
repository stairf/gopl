#!/usr/bin/perl

my $config = $ARGV[0];
my $src    = $ARGV[1];

our @options;

do $config;

my $types = {
	string => {
		generate_has => 1,
		generate_get => 1,
		format => "%s",
	},
	int => {
		generate_has => 1,
		generate_get => 1,
		format => "%d",
	},
	lint => {
		generate_has => 1,
		generate_get => 1,
		format => "%ld",
	},
	llint => {
		generate_has => 1,
		generate_get => 1,
		format => "%lld",
	},
	float => {
		generate_has => 1,
		generate_get => 1,
		format => "%f",
	},
	lfloat => {
		generate_has => 1,
		generate_get => 1,
		format => "%lf",
	},
	lfloat => {
		generate_has => 1,
		generate_get => 1,
		format => "%llf",
	},
	xint => {
		generate_has => 1,
		generate_get => 1,
		format => "%x",
	},
	lxint => {
		generate_has => 1,
		generate_get => 1,
		format => "%lx",
	},
	llxint => {
		generate_has => 1,
		generate_get => 1,
		format => "%llx",
	},
	char => {
		generate_has => 1,
		generate_get => 1,
		format => "%c",
	},
	flag => {
		generate_get => 1,
		format => "%d",
	},
	counter => {
		generate_get => 1,
		format => "%d",
	},
	switch => {
		generate_get => 1,
		format => "%d",
	},
	enum => {
		generate_has => 1,
		generate_get => 1,
		format => "%d",
	},
};

open my $out,">$src" or die "failed to open $src: $!\n";

my $gopl_header = $src;
$gopl_header =~ s/.c$/.gopl.h/;

print $out qq @
/*
 * $out
 */
#include "common.h"
#include "$gopl_header"

int main(int argc, const char **argv)
{
	struct opt_options o;
	memset(&o, 0, sizeof(o));
	int x = opt_parse(argc, argv, &o);
	if (x < 0)
		exit(EXIT_FAILURE);
	else if (x > 0)
		exit(EXIT_SUCCESS);

@;

for my $o (@options) {
	my $type = $o->{type};
	my $short = $o->{short};
	my $long = $o->{long};
	my $t = $types->{$type};
	die "unknown type: $type\n" unless $t;
	if ($t->{generate_has} and !defined $o->{init}) {
		print $out qq @
			if (opt_${_}_given(o)) {
				printf("$_='$t->{format}' ", opt_${_}_value(o));
			}
		@ for map { s/-/_/gr } split ',', $long;
		print $out qq @
			if (opt_${short}_given(o)) {
				printf("$short='$t->{format}' ", opt_${short}_value(o));
			}
		@ if defined $short;
	} elsif ($t->{generate_get}) {
		print $out qq @
			printf("$_='$t->{format}' ", opt_${_}_value(o));
		@ for map { s/-/_/gr } split ',', $long;
		print $out qq @
			printf("$short='$t->{format}' ", opt_${short}_value(o));
		@ if defined $short;
	} else {
		die "cannot test option { " . (join ", ", map { "$_ => '$o->{$_}'" } keys %$o) . " } \n"
	}
}

print $out qq @
	for (int i = 0; i < opt_nargs(o); ++i) {
		printf("\@%d='%s' ", i, opt_arg(o,i));
	}
	printf("\\n");
	exit(0);
@;


print $out qq @

} /* main */
@;

close $out or die "failed to close $src: $!\n";

