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

my $disk_name;
my $disk_size;

if($out_file =~ /d82.trk$/)
{
	$disk_name = "tmp.d82";
	$disk_size = 1066496;
}
else
{
	$disk_name = "tmp.d80";
	$disk_size = 533248;
}

mkdir "tmp";

open FILE, ">tmp/" . $disk_name;
binmode FILE;
seek FILE, 274688, SEEK_SET;
print FILE $stub_data;
seek FILE, $disk_size-1, SEEK_SET;
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
	
	system("c1541 tmp/" . $disk_name . " -write " . $pc_file . " " . $cbm_file);
}


#######################################################################################
#
# Extract tracks 38-39 to the output file.
#
#######################################################################################

my $in_data;

open FILE, "tmp/" . $disk_name;
binmode FILE;
seek FILE, 274688, SEEK_SET;
read(FILE, $in_data, 14848);
close FILE;

open FILE, ">" . $out_file;
binmode FILE;
print FILE $in_data;
close FILE;
