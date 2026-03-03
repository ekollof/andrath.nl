#!/usr/bin/perl

use strict;
use warnings;

# Preprocess .ms files to handle code snippets for groff
# Usage: ./preprocess-code.pl input.ms > output.ms

if (@ARGV != 1) {
    die "Usage: $0 input.ms\n";
}

my $input_file = $ARGV[0];

if (!-f $input_file) {
    die "Error: Input file $input_file not found\n";
}

open(my $fh, '<', $input_file) or die "Cannot open $input_file: $!\n";

my $in_code_block = 0;
my $language = "";
my @code_lines;

while (my $line = <$fh>) {
    chomp($line);

    if ($line =~ /^\.CODE(?:\s+(\S+))?$/) {
        $in_code_block = 1;
        $language = $1 // "none";
        @code_lines = ();
        print ".HTML <pre class=\"language-$language line-numbers\"><code class=\"language-$language\">\n";
        next;
    }
    elsif ($line =~ /^\.ENDCODE$/) {
        $in_code_block = 0;
        $language = "";
        # Emit each line individually via .HTML to avoid groff swallowing
        # embedded newlines in a single multi-line .HTML argument.
        for my $code_line (@code_lines) {
            # Escape HTML entities: & first, then < and >
            $code_line =~ s/&/&amp;/g;
            $code_line =~ s/</&lt;/g;
            $code_line =~ s/>/&gt;/g;
            print ".HTML $code_line\n";
        }
        print ".HTML </code></pre>\n";
        print ".PP\n";
        @code_lines = ();
        next;
    }

    if ($in_code_block) {
        push @code_lines, $line;
    } else {
        print "$line\n";
    }
}

close($fh);
