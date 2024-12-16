#!/usr/bin/perl

use strict;
use warnings;

my $grade = $ARGV[0];

if ($grade =~ /^(A|B|C|D|F|NA)$/) {
    print $grade;
    exit 0;
} else {
    print "Invalid\n";
    exit 1;
}
