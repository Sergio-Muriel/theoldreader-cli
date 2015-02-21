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
my $debug;
my $command;
my $id;
my @params;

# Grab options and commands
GetOptions (
        'config=s' => \$config,
        'debug' => \$debug,
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

if(!$config)
{
    $config = TheOldReader::Constants::DEFAULT_CONFIG;
}

if(!-f $config)
{
    croak("No configuration file found. Run ./reader.pl create_config to create one.");
}

my $obj = TheOldReader::GuiShared->new(
        'background_job' => [],
        'gui_job' => []
);

my $bg =threads->create(sub {
    my $background = TheOldReader::GuiBackground->new('debug' => $debug, 'config' => $config, 'share' => $obj);
    $background->thread_init();
    $background->log("DONE thread bg ! ");
});
$bg->detach();

my $client = TheOldReader::Gui->new('debug' => $debug, 'config' => $config, 'share' => $obj);
$client->init();


