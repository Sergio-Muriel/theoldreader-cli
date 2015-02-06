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

sub add_gui_job()
{
    my ($self, $job) = @_;
    $self->log($self->{'share'}),
    $self->{'share'}->add("gui_job", $job);
}

sub thread_init()
{
    my ($self, @params) = @_;

    while(1)
    {
        my $command = $self->{'share'}->shift('background_job');
        if($command)
        {
            if($self->can($command))
            {
                $self->log("Running command $command");
                $self->$command;
                $self->log("Command $command done.");
            }
            else
            {
                $self->log("FATAL ERROR: unknown command $command");
            }
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


1;

__END__

