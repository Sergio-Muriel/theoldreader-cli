#!/usr/bin/perl -w
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use Carp qw(croak);
use TheOldReader::GuiShared;
use TheOldReader::GuiBackground;
use TheOldReader::Gui;
use threads;
use threads::shared;


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

my $obj = TheOldReader::GuiShared->new(
        'background_job' => [],
        'gui_job' => []
);

my $client = TheOldReader::Gui->new( 'config' => $config, 'share' => $obj);
my $background = TheOldReader::GuiBackground->new( 'config' => $config, 'share' => $obj);

$background->init();
$client->init();


