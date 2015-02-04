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

sub fetch_labels()
{
    my ($self) = @_;
    print "Fetching labels from server...\n";

    my $list =  $self->{'reader'}->labels();
    if(!$list)
    {
        $self->error("Cannot get labels from server. Check configuration.");
        exit();
    }
    my %return = (
        'labels' => {},
        'values' => []
    );

    foreach my $ref(keys %{$list})
    {
        $return{'labels'}{$ref} = $$list{$ref};
        push(@{$return{'values'}}, $ref);
    }
    $self->{'cache'}->save_cache("labels",$list);
    $self->{'labels'} = \%return;
}

sub update_labels()
{
    my ($self, @params) = @_;
    my %labels = %{$self->{'labels'}};

    $self->{'left_container'}->labels($labels{'labels'});
    $self->{'left_container'}->values($labels{'values'});
    $self->{'cui'}->draw();
}


sub loop
{
    my ($self, @params) = @_;

    $self->fetch_labels();

    $self->{'cui'} =new Curses::UI(
        -color_support => 1,
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
        -y    => 1,
        -bfg  => 'white',
        -values => [ 1 ],
        -labels => { 1 => 'Loading...'}
    );

    $self->{'left_container'} = $self->{'container'}->add(
        'left_container',
        'Listbox',
        -width => 30,
        -y    => 0,
        -bfg  => 'white',
        -values => [ 1 ],
        -labels => { 1 => 'Loading...'}
    );

    $self->update_labels();

    #$self->{'cui'}->set_timer('update_time', sub { $self->update_labels(); } );

    $self->{'right_container'} = $self->{'container'}->add(
        'right_container',
        'Listbox',
        -border => 0,
        -y    => 0,
        -x => 30,
        -bg => 'blue',
        -fg => 'white',
        -labels => {
                1 => 'one',
                2 => 'two',
        },
        -values => [ 1, 2 ]
    );

    $self->bind_keys();
    $self->{'left_container'}->focus();
    $self->{'right_container'}->draw();
    $self->{'cui'}->mainloop();
}

sub bind_keys()
{
    my ($self, @params) = @_;
    my $exit_ref = sub { $self->exit_dialog(); };

    $self->{'cui'}->set_binding($exit_ref, "\cC");
    $self->{'cui'}->set_binding($exit_ref, "\cQ");
}
sub exit_dialog()
{
    exit(0);
}


1;

__END__

