#!/usr/bin/perl

use strict;
use warnings;

# Normalize HTML output from groff to fix extra newlines within <code> tags
# Usage: ./normalize-html.pl input.html > output.html

my $in_code_block = 0;
my $code_block = "";
my @output_lines = ();

while (my $line = <>) {
    chomp $line;

    if ($line =~ /<code class="code-snippet language-[^"]*">/) {
        $in_code_block = 1;
        $code_block = "$line\n";
        next;
    }
    elsif ($line =~ /<\/code>/) {
        $in_code_block = 0;
        $code_block .= "$line\n";
        # Normalize newlines: collapse three or more consecutive newlines into two
        $code_block =~ s/\n{3,}/\n\n/g;
        # Remove leading/trailing newlines within the code block, but ensure one trailing newline
        $code_block =~ s/^\n+//;
        $code_block =~ s/\n+$/\n/;
        print $code_block;
        next;
    }

    if ($in_code_block) {
        $code_block .= "$line\n";
    } else {
        print "$line\n";
    }
}
