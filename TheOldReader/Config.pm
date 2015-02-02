package TheOldReader::Config;

use Exporter;
use Storable;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
use IO::Prompt;
use TheOldReader::Constants;

$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = ();

use strict;
use warnings;
use Carp qw(croak);
use Data::Dumper;

sub read_config()
{
    my ($self) = @_;
    # Read configuration
    if(!-f $self->{'config'})
    {
        return $self->output_error("Error: configuration file ".$self->{'config'}."  not found.");
    }
    if(!-r $self->{'config'})
    {
        return $self->output_error("Error: cannot read file ".$self->{'config'});
    }
    open(CONFIG, $self->{'config'});
    while(<CONFIG>)
    {
        /^token:(.*)$/ and $self->{'token'}=$1;
        /^max_items_displayed:(\d+)$/ and $self->{'max_items_displayed'}=$1;
    }
    close(CONFIG);
}

sub save_cache()
{
    my ($self,$name,$hash_ref) = @_;
    if(!-d TheOldReader::Constants::CACHE_DIR)
    {
        mkdir(TheOldReader::Constants::CACHE_DIR);
    }
    store($hash_ref, TheOldReader::Constants::CACHE_DIR.$name);
    #$hashref = retrieve('file');
}

1;
