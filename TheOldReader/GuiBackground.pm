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
    $self->{'share'}->add('gui_job','update_count');
}

sub labels()
{
    my ($self, @params) = @_;
    # Init labels
    $self->{'reader'}->labels();
    $self->{'share'}->add('gui_job','update_labels');

}

sub last()
{
    my ($self, @params) = @_;
    my $params = shift(@params);

    my ($id, $only_unread) = ($params =~ /^(\S+)\s+(.*)$/);
    if(!$id)
    {
        $id=TheOldReader::Constants::FOLDER_ALL;
    }

    my $items;
    if($only_unread)
    {
        $items = $self->{'reader'}->unread($id, $self->{'max_items_displayed'});
    }
    else
    {
        $items = $self->{'reader'}->last($id, $self->{'max_items_displayed'});
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
    $self->{'share'}->add('gui_job','update_last '.$id);
}


sub add_gui_job()
{
    my ($self, $job) = @_;
    $self->{'share'}->add("gui_job", $job);
}

sub thread_init()
{
    my ($self) = @_;

    while(1)
    {
        my $received = $self->{'share'}->shift('background_job');
        if($received)
        {
            my ($command, $params)  = ($received=~ /^(\S+)(?:$|\s(.*)$)/);
            if($self->can($command))
            {
                #$self->log("Running command $received");
                $self->$command($params);
                #$self->log("Command $received done.");
            }
            else
            {
                $self->log("FATAL ERROR: unknown command $command");
            }
        }
        else
        {
            select(undef,undef,undef,0.2);
        }
    }
}

sub log()
{
    my ($self, $command) = @_;
    open(WRITE,">>log"),
    print WRITE "BG: $command\n";
    close WRITE;
}


1;

__END__

