#!/usr/bin/perl

use Win32::SerialPort;
use Time::HiRes;

$port = "COM1";
$file = $ARGV[0];
die "File name must be given!" unless $file;

open FILE, $file or die "Cannot open input file!";
binmode FILE;

$COM = Win32::SerialPort->new($port);
die "Cannot open port $port!" unless $COM;

$COM->baudrate(9600);
$COM->parity("N");
$COM->databits("8");
$COM->stopbits("1");
$COM->handshake("none");

if(!$ARGV[1])
{
    print "Waiting for handshake...\n";

    $byte = wait_for_byte();
    die "Invalid handshake: " . ord($byte) unless $byte == 22;
}

print "Handshake received, starting transfer...\n";
$COM->write(chr(22));

while(true)
{
	while(true)
	{
		$byte = wait_for_byte();
		$COM->write($line) if $byte == 21;
		last if $byte == 6;
	}
	$len = read FILE, $buf, 32;
	
	if(!$len)
	{
		$COM->write(":00");
		print ":00\n";
		print "Transmission complete.\n";
		last;
	}
	else
	{
		$line = ":20";
		$sum = 0;
		for($i = 0; $i < 32; $i++)
		{
			$byte = ord(substr($buf, $i, 1));
			$line .= sprintf("%02X", $byte);
			$sum = ($sum + $byte) & 255;
		}
		$line .= sprintf("%02X", (256-$sum) & 255);
		$COM->write($line);
		print $line, "\n";
	}
}

sub wait_for_byte()
{
	my $byte;
	while(!($byte = $COM->input)) {}
	return ord(substr($byte, -1));
}
