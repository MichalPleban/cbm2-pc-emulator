#!/usr/bin/perl

$file = $ARGV[0];

open FILE, $file || die "Cannot open the input file!";
$text = join "", <FILE>;
close FILE;

$text =~ /SOFTWARE_BUILD\s+equ\s+([0-9]+)/ || die "Cannot find build number in the input file!";
$build = 1+$1;

$text =~s /SOFTWARE_BUILD\s+equ\s+([0-9]+)/SOFTWARE_BUILD equ $build/;
$text =~s /SOFTWARE_BUILDS\s+equ\s+\"([0-9]+)\"/SOFTWARE_BUILDS equ \"$build\"/;

open FILE, ">" . $file;
print FILE $text;
close FILE;
