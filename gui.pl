#!/usr/bin/perl -w
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use Carp qw(croak);
use TheOldReader::Gui;


my $config;
my $command;
my $id;
my @params;

# Grab options and commands
GetOptions (
        'config=s' => \$config,
        '<>', \&params
);

sub params
{
    if(!$command)
    {
        $command = shift;
    }
    else
    {
        push(@params, shift);
    }
}

my $client = TheOldReader::Gui->new(
   'config' => $config,
);
$client->loop();

