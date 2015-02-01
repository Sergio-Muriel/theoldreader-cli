#!/usr/bin/perl -w
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use Carp qw(croak);
use TheOldReader::Cli;


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

my $client = TheOldReader::Cli->new(
   'config' => $config,
);

if(!$command)
{
    $client->help();
}
elsif($client->can($command))
{
    $client->$command(@params);
}
else
{
    croak "Unknown command $command";
}



1;

