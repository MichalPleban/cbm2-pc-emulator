#!/usr/bin/perl

$file = $ARGV[0];

open FILE, $file || die "Cannot open the input file!";
$text = join "", <FILE>;
close FILE;

$text =~ /%define\s+SOFTWARE_BUILD\s+([0-9]+)/ || die "Cannot find build number in the input file!";
$build = 1+$1;

$text =~s /%define\s+SOFTWARE_BUILD\s+([0-9]+)/%define SOFTWARE_BUILD $build/;
$text =~s /%define\s+SOFTWARE_BUILDS\s+\"([0-9]+)\"/%define SOFTWARE_BUILDS \"$build\"/;

open FILE, ">" . $file;
print FILE $text;
close FILE;
