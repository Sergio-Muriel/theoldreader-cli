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
        /^only_unread:(\d*)$/ and $self->{'only_unread'}=$1;
        /^labels_unread:(\d*)$/ and $self->{'labels_unread'}=$1;
        /^display_feeds:(\d*)$/ and $self->{'display_feeds'}=$1;
        /^browser:(.*)$/ and $self->{'browser'}=$1;
    }
    close(CONFIG);
}
sub save_config()
{
    my ($self) = @_;
    open(WRITE, ">".$self->{'config'});
    print WRITE "token:".$self->{'token'}."\n";
    print WRITE "max_items_displayed:".$self->{'max_items_displayed'}."\n";

    if($self->{'display_feeds'})
    {
        print WRITE "display_feeds:".$self->{'display_feeds'}."\n";
    }
    else
    {
        print WRITE "display_feeds:0\n";
    }
    if($self->{'only_unread'})
    {
        print WRITE "only_unread:".$self->{'only_unread'}."\n";
    }
    else
    {
        print WRITE "only_unread:0\n";
    }
    if($self->{'labels_unread'})
    {
        print WRITE "labels_unread:".$self->{'labels_unread'}."\n";
    }
    else
    {
        print WRITE "labels_unread:1\n";
    }

    if($self->{'browser'})
    {
        print WRITE "browser:".$self->{'browser'}."\n";
    }
    else
    {
        print WRITE "browser:x-www-browser\n";
    }
    close WRITE;
}


1;
