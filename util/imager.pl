#!/usr/bin/perl

use strict;

use Getopt::Std;
use File::Basename;
use File::Spec;
 
my(%options);

getopt('ioOtbs', \%options); 

#######################################################################################
#
# Set input and output filenames
#
#######################################################################################

my $in_file = $options{"i"};
my $out_file = $options{"o"};

die "Input file not specified. Use -i option to specify it.\n" unless $in_file;
die "Output file not specified. Use -o option to specify it.\n" unless $out_file;

die "Unable to find input file '$in_file'.\n" unless -f $in_file;


#######################################################################################
#
# Set image type (D80 or D82)
#
#######################################################################################

my $out_type;

if(defined $options{"t"})
{
	$out_type = $options{"t"};
}
else
{
	($out_type) = $out_file =~ /\.([^.]+)$/;
}

$out_type =~tr/A-Z/a-z/;
die "Unknown output image type. Use -t option to specify it (D80 or D82).\n" if($out_type ne "d80" && $out_type ne "d82");


#######################################################################################
#
# Load input image.
#
#######################################################################################

my $in_data;

open FILE, $in_file || die "Unable to open input file '$in_file'.\n";
binmode FILE;
read(FILE, $in_data, 746497);
close FILE;

my $in_size = length($in_data);


#######################################################################################
#
# Calculate input image size.
#
#######################################################################################

my $in_type;

$in_type = 720 if $in_size == 737280;
$in_type = 360 if $in_size == 368640;
$in_type = 180 if $in_size == 184320;
$in_type = 160 if $in_size == 163840;

die "Unsupported image size. Only 160kB, 180kB, 360kB and 720kB images are supported.\n" unless $in_type;
die "Image too big to fit in a D80 disk. Try D82 instead.\n" if $in_type == 720 and $out_type eq "d80";


#######################################################################################
#
# Set filename for BAM and directory stub.
#
#######################################################################################

my $stub_file;

if(defined $options{"s"})
{
	$stub_file = $options{"s"};
}
else
{
	$stub_file = $in_type . "_" . $out_type . ".trk";
	my $sep = File::Spec->catfile('', '');
	if(!$options{"b"})
	{
		$stub_file = dirname($0) . $sep . $stub_file;
	}
	else
	{
		$stub_file = $options{"b"} . $sep . $stub_file;
	}
}

die "Unable to find stub file '$stub_file'.\n" unless -f $stub_file;


#######################################################################################
#
# Load stub data.
#
#######################################################################################

my $stub_data;

open FILE, $stub_file || die "Unable to open stub file '$stub_file'.\n";
binmode FILE;
read(FILE, $stub_data, 22273);
close FILE;

my $stub_size = length($stub_data);

die "Invalid stub file size (should be 14848 bytes).\n" unless $stub_size = 22272;


#######################################################################################
#
# Prepare output image.
#
#######################################################################################

my $out_size;

$out_size = 533248 if $out_type eq "d80";
$out_size = 1066496 if $out_type eq "d82";

my $out_data = chr(0) x $out_size;

substr($out_data, 267264, 22272) = $stub_data;
if($in_size < 267264)
{
	substr($out_data, 0, $in_size) = $in_data;
}
else
{
	substr($out_data, 0, 267264) = substr($in_data, 0, 267264);
	substr($out_data, 289536, length($in_data)-267264) = substr($in_data, 267264);
}


#######################################################################################
#
# Write output image.
#
#######################################################################################

open FILE, ">" . $out_file || die "Cannot open output file '$out_file'.\n";
binmode FILE;
print FILE $out_data;
close FILE;
