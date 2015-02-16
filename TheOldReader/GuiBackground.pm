package TheOldReader::GuiBackground;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION     = 1.00;
@ISA         = qw(Exporter TheOldReader::Config);
@EXPORT      = ();

use strict;
use warnings;
use LWP::UserAgent;
use JSON;
use Carp qw(croak);
use TheOldReader::Config;
use TheOldReader::Api;
use TheOldReader::Constants;
use TheOldReader::Cache;

use threads;
use Curses::UI;
use Data::Dumper;

# Create new instance
sub new
{
    my ($class, %params) = @_;
    my $self = bless { %params }, $class;

    if($params{'config'})
    {
        $self->{'config'} = $params{'config'};
    }
    else
    {
        $self->{'config'} = TheOldReader::Constants::DEFAULT_CONFIG;
    }

    $self->read_config();
    $self->{'share'} = $params{'share'};
    $self->{'cache'} = TheOldReader::Cache->new();

    $self->{'reader'} = TheOldReader::Api->new(
       'host' => TheOldReader::Constants::DEFAULT_HOST,
       'token' => $self->{'token'},
    );
    return $self;
}

sub error()
{
    my ($self, $message) = @_;
    print STDERR "Error: $message\n";
}



sub init
{
    my ($self, @params) = @_;

    my $trd = threads->create(sub { $self->thread_init(); });
    $trd->detach();
}

sub unread_feeds()
{
    my ($self, @params) = @_;
    # Init labels
    $self->{'reader'}->unread_feeds();
    $self->add_gui_job("update_count");
}

sub labels()
{
    my ($self, @params) = @_;
    # Init labels
    $self->{'reader'}->labels();
    $self->add_gui_job("update_labels");

}

sub mark_starred()
{
    my ($self, $id) = @_;
    my @ids = ($id);
    my $result = $self->{'reader'}->mark_starred(@ids);
    my $contents = $self->{'reader'}->contents(@ids);
    if($contents)
    {
        foreach(@{$$contents{'items'}})
        {
            $self->{'cache'}->save_cache("item ".$_->{'id'}, $_);
        }
    }
    $id=~ s/tag\:google\.com\,2005\:reader\/item\///g;
    $self->add_gui_job("last_status $id");
}

sub unmark_starred()
{
    my ($self, $id) = @_;
    my @ids = ($id);
    my $result = $self->{'reader'}->unmark_starred(@ids);
    my $contents = $self->{'reader'}->contents(@ids);
    if($contents)
    {
        foreach(@{$$contents{'items'}})
        {
            $self->{'cache'}->save_cache("item ".$_->{'id'}, $_);
        }
    }
    $id=~ s/tag\:google\.com\,2005\:reader\/item\///g;
    $self->add_gui_job("last_status $id");
}

sub mark_read()
{
    my ($self, $id) = @_;
    my @ids = ($id);
    my $result = $self->{'reader'}->mark_read(\@ids);
    my $contents = $self->{'reader'}->contents(@ids);
    if($contents)
    {
        foreach(@{$$contents{'items'}})
        {
            $self->{'cache'}->save_cache("item ".$_->{'id'}, $_);
        }
    }
    $self->add_gui_job("last_status $id");
}
sub mark_unread()
{
    my ($self, $id) = @_;
    my @ids = ($id);
    my $result = $self->{'reader'}->mark_unread(\@ids);
    my $contents = $self->{'reader'}->contents(@ids);
    if($contents)
    {
        foreach(@{$$contents{'items'}})
        {
            $self->{'cache'}->save_cache("item ".$_->{'id'}, $_);
        }
    }
    $self->add_gui_job("last_status $id");
}


sub last()
{
    my ($self, @params) = @_;
    my $params = shift(@params);

    my ($clear,$id, $only_unread, $next_id) = split(/\s+/,$params);
    if(!$id)
    {
        $id=TheOldReader::Constants::FOLDER_ALL;
    }
    if(!$next_id)
    {
        $next_id="";
    }

    my $items;
    if($only_unread)
    {
        $items = $self->{'reader'}->unread($id, $self->{'max_items_displayed'}, $next_id);
    }
    else
    {
        $items = $self->{'reader'}->last($id, $self->{'max_items_displayed'}, $next_id);
    }

    $self->{'cache'}->save_cache("last $id", $items);
    if(!$items)
    {
        return $self->output_error("Cannot get last items. Check out configuration.");
    }
    my @hash_ids = @{$$items{'itemRefs'}};
    my @ids = ();
    foreach(@hash_ids)
    {
        my $id= $_->{'id'};
        push(@ids, $id);
    }

    # Get content of uncached items
    if(@hash_ids)
    {
        my $contents = $self->{'reader'}->contents(@ids);
        if($contents)
        {
            foreach(@{$$contents{'items'}})
            {
                $self->{'cache'}->save_cache("item ".$_->{'id'}, $_);
            }
        }
    }

    # Dont wait for content items to load list
    $self->add_gui_job("display_list $clear $id");
}


sub add_gui_job()
{
    my ($self, $job) = @_;
    $self->{'share'}->add("gui_job", $job);
}

sub thread_command()
{
    my ($self, $received) = @_;
    if($received)
    {
        my ($command, $params)  = ($received=~ /^(\S+)(?:$|\s(.*)$)/);
        if($self->can($command))
        {
            $self->$command($params);
        }
        else
        {
            $self->log("FATAL ERROR: unknown command $command");
        }
    }
}

sub thread_init()
{
    my ($self) = @_;

    while(1)
    {
        my $received;
        while($received = $self->{'share'}->shift('background_job'))
        {
            my $trd = threads->create(sub { $self->thread_command($received); });
            $trd->detach();
        }
        select(undef,undef,undef,0.5);
    }
}

sub log()
{
    my ($self, $command) = @_;
    open(WRITE,">>log"),
    print WRITE "BG: $command\n";
    close WRITE;
}

sub output_error()
{
    my ($self, $error) = @_;
    print STDERR $error."\n";
}


1;

__END__

