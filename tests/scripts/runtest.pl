#!/usr/bin/perl

my $bin = $ARGV[0];
my $infile = $ARGV[1];

sub Die {
	print @_;
	exit 1;
}

close STDERR;
open my $in,"<$infile" or Die "failed to open $infile: $!\n";

my $line = 1;
while (<$in>) {
	next unless $_;
	next if /^#/;

	if (s/^<//) {
		my @args = split ' ';
		my $expected = <$in>;
		open my $out, "-|", $bin, @args or Die "failed to start $bin: $!\n";
		my $is = <$out>;
		my @words = sort split ' ', $is;
		my @exp = sort split ' ', $expected;
		Die "$line: wrong number of words: " . (scalar @words) . "\n" unless $#words == $#exp;
		for (my $i = 0; $i < scalar @words; ++$i) {
			if ($words[$i] ne $exp[$i]) {
				Die "$line: bad word: is=$words[$i] exp=$exp[$i]\n";
			}
		}
		close $out or Die "$line: exit status $?\n";
		$line++;
	} elsif (s/^!//) {
		my @args = split ' ';
		open my $out, "-|", $bin, @args or Die "failed to start $bin: $!\n";
		my $is = <$out>;
		close $out;
		Die "$line: did not fail: $?\n" unless $?;
	}

} continue {
	$line++;
}

close $in;
exit 0;

