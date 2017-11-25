#!/usr/bin/perl

use strict;

use File::Basename;
use Fcntl qw(SEEK_SET);


#######################################################################################
#
# Check if the "c1541" utility is installed and all required parameters are provided.
#
#######################################################################################

die "Usage: insert.pl input_stub output_stub file1 ...\n" unless @ARGV >= 3;

my $in_file = shift @ARGV;
my $out_file = shift @ARGV;

my $tmp = `c1541 -h`;
die "The 'c1541' utility is not installed.\n" unless $tmp;


#######################################################################################
#
# Load input track data.
#
#######################################################################################

my $stub_data;

open FILE, $in_file || die "Could not load input stub file: " . $in_file . "\n";
binmode FILE;
read(FILE, $stub_data, 14849);
close FILE;

my $stub_size = length($stub_data);

die "Invalid stub file size (should be 14848 bytes).\n" unless $stub_size = 14848;


#######################################################################################
#
# Create disk image with specified track data.
#
#######################################################################################

mkdir "tmp";

open FILE, ">tmp/tmp.d82";
binmode FILE;
seek FILE, 274688, SEEK_SET;
print FILE $stub_data;
seek FILE, 1066495, SEEK_SET;
print FILE chr(0);
close FILE;


#######################################################################################
#
# Insert the files usting c1541 utility.
#
#######################################################################################

my $pc_file;
my $cbm_file;

while($pc_file = shift @ARGV)
{
	$cbm_file = basename($pc_file);
	$cbm_file =~s /\..*//;
	
	system("c1541 tmp/tmp.d82 -write " . $pc_file . " " . $cbm_file);
}


#######################################################################################
#
# Extract tracks 38-39 to the output file.
#
#######################################################################################

my $in_data;

open FILE, "tmp/tmp.d82";
binmode FILE;
seek FILE, 274688, SEEK_SET;
read(FILE, $in_data, 14848);
close FILE;

open FILE, ">" . $out_file;
binmode FILE;
print FILE $in_data;
close FILE;
