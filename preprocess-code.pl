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
        print ".br\n";
        print ".ns\n"; # No-space mode to suppress extra spacing
        print ".nf\n";
        print ".ft 5\n";
        print ".HTML <code class=\"code-snippet language-$language\">\n";
        next;
    }
    elsif ($line =~ /^\.ENDCODE$/) {
        $in_code_block = 0;
        $language = "";
        # Escape backslashes and HTML entities
        $code_block =~ s/\\/\\\\/g;  # \n -> \\n
        $code_block =~ s/</\</g;    # < -> <
        $code_block =~ s/>/\>/g;    # > -> >
        $code_block =~ s/&/\&/g;    # & -> &
        print "$code_block\n";
        print ".HTML </code>\n";
        print ".ft R\n";
        print ".fi\n";
        print ".rs\n"; # Restore spacing mode
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
