package TheOldReader::Gui;
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
use Curses::UI::POE;
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
    $self->{'cache'} = TheOldReader::Cache->new();
    $self->{'share'} = $params{'share'};

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


sub update_labels()
{
    my ($self, @params) = @_;
    $self->{'labels'} = $self->{'cache'}->load_cache('labels');
    if(!$self->{'labels'})
    {
        return;
    }
    my %labels = %{$self->{'labels'}};

    my %gui_labels = (
        'labels' => {},
        'values' => []
    );

    foreach my $ref(keys %labels)
    {
        $gui_labels{'labels'}{$ref} = $labels{$ref};
        push(@{$gui_labels{'values'}}, $ref);
    }

    $self->{'left_container'}->labels($gui_labels{'labels'});
    $self->{'left_container'}->values($gui_labels{'values'});
    $self->{'statusbar'}->text("Labels updated.");

    $self->log("Update gui?");
    $self->{'statusbar'}->text("OK!");

    $self->{'container'}->draw();
    #$self->{'bottombar'}->focus();
    #$self->{'left_container'}->focus();
    $self->{'cui'}->draw(1);
    $self->log("Final!");
}
sub nada
{
    my ($self, @params) = @_;
}


sub init
{
    my ($self, @params) = @_;


    # Build gui
    $self->build_gui();

    # Run background jobs
    $self->add_background_job("labels", "Updating labels...");


    # Loo gui
    $self->run_gui();

}

sub build_gui()
{
    my ($self, @params) = @_;

    $self->{'cui'} = new Curses::UI::POE(
        -color_support => 1,
        inline_states => {
            _start => sub {
                $_[HEAP]->{next_alarm_time} = int(time()) + 1;
                $_[KERNEL]->alarm(tick => $_[HEAP]->{next_alarm_time});
            },
            tick => sub{
                $self->loop_event();
                $_[HEAP]->{next_alarm_time}++;
                $_[KERNEL]->alarm(tick => $_[HEAP]->{next_alarm_time});
            },

            _stop => sub {
                #$_[HEAP]->dialog("Good bye!");
            },
        }
    );

    $self->{'window'} = $self->{'cui'}->add(
        'win1', 'Window',
    );

    $self->{'topbar'} = $self->{'window'}->add(
        'topbar',
        'Container',
        -y    => 0,
        -bg => 'blue',
        -fg => 'white'
    );

    $self->{'topbar'}->add(
        'text',
        'Label',
        -bold => 1,
        -text => 'The Old Reader - GUI'
    );


    $self->{'container'} = $self->{'window'}->add(
        'container',
        'Container',
        -border => 1,
        -height => $ENV{'LINES'} - 2,
        -y    => 1,
        -bfg  => 'white'
    );

    $self->{'left_container'} = $self->{'container'}->add(
        'left_container',
        'Listbox',
        -width => 30,
        -bfg  => 'white',
        -values => [ 1,2 ],
        -labels => { 1 => 'Loading...', 2 => ''}
    );

    $self->{'right_container'} = $self->{'container'}->add(
        'right_container',
        'Listbox',
        -border => 0,
        -x => 30,
        -bg => 'blue',
        -fg => 'white',
        -labels => {
                1 => 'one',
                2 => 'two',
        },
        -values => [ 1, 2 ]
    );

    # FOOTER
    $self->{'bottombar'} = $self->{'window'}->add(
        'bottombar',
        'Container',
        -width => $ENV{'COLS'},
        -y    => $ENV{'LINES'}-1,
        -height => 1,
        -bg => 'black',
        -fg => 'white'
    );
    $self->{'statusbar'} = $self->{'bottombar'}->add(
        'text',
        'Label',
        -bold => 1,
        -text => 'Loading...'
    );

    $self->bind_keys();
    $self->{'bottombar'}->focus();
    $self->{'left_container'}->focus();
    $self->{'right_container'}->draw();
}

sub run_gui()
{
    my ($self) = @_;
    $self->{'cui'}->mainloop();
}

sub add_background_job()
{
    my ($self, $job, $status_txt) = @_;
    $self->log($self->{'share'}),
    $self->{'statusbar'}->text($status_txt);

    $self->{'share'}->add("background_job", $job);
}


# Runned every 1 second to check if there is something from background job to run
sub loop_event()
{
    my ($self, @params) = @_;
    $self->log("in loop event");
    
    my $command = $self->{'share'}->shift('gui_job');
    if($command)
    {
        $self->log("received command $command");
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
}

sub log()
{
    my ($self, $command) = @_;
    open(WRITE,">>log"),
    print WRITE "GUI: $command\n";
    close WRITE;
}

sub bind_keys()
{
    my ($self, @params) = @_;
    my $exit_ref = sub { $self->exit_dialog(); };

    $self->{'cui'}->set_binding($exit_ref, "\cC");
    $self->{'cui'}->set_binding($exit_ref, "q");
    $self->{'cui'}->set_binding($exit_ref, "\cQ");
}
sub exit_dialog()
{
    exit(0);
}


1;

__END__

