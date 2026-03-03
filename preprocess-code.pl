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
my $code_block = "";

while (my $line = <$fh>) {
    chomp($line); # Remove trailing newline for processing

    if ($line =~ /^\.CODE(?:\s+(\S+))?$/) {
        $in_code_block = 1;
        $language = $1 // "none";
        $code_block = "";
        print ".HTML <pre class=\"language-$language line-numbers\"><code class=\"language-$language\">\n";
        next;
    }
    elsif ($line =~ /^\.ENDCODE$/) {
        $in_code_block = 0;
        $language = "";
        # Escape HTML entities
        $code_block =~ s/&/&amp;/g;   # & -> &amp;  (must be first)
        $code_block =~ s/</&lt;/g;    # < -> &lt;
        $code_block =~ s/>/&gt;/g;    # > -> &gt;
        print ".HTML $code_block\n";
        print ".HTML </code></pre>\n";
        print ".PP\n";
        next;
    }

    if ($in_code_block) {
        # Collect lines into code_block
        if ($code_block eq "") {
            $code_block = $line;
        } else {
            $code_block .= "\n$line";
        }
    } else {
        print "$line\n"; # Print with literal newline
    }
}

close($fh);
