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

    $self->{'reader'} = TheOldReader::Api->new(
       'host' => TheOldReader::Constants::DEFAULT_HOST,
       'token' => $self->{'token'},
    );
    return $self;
}

sub labels()
{
    my ($self) = @_;
    my $list =  $self->{'reader'}->labels();
    my %return = (
        'labels' => {},
        'values' => []
    );

    foreach my $ref(keys %{$list})
    {
        $return{'labels'}{$ref} = $$list{$ref};
        push($return{'values'}, $ref);
    }
    $self->save_cache("labels",$list);
    return %return;
}



sub loop
{
    my ($self, @params) = @_;
    my %labels = $self->labels();

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

    $self->{'bottombar'} = $self->{'window'}->add(
        'bottombar',
        'Dialog::Status',
        -message => 'test'
    );

    $self->{'left_container'} = $self->{'window'}->add(
        'left_container',
        'Listbox',
        -width => 20,
        -border => 1,
        -y    => 1,
        -bfg  => 'white',
        -labels => $labels{'labels'},
        -values => $labels{'values'}
    );

    $self->{'right_container'} = $self->{'window'}->add(
        'right_container',
        'Listbox',
        -border => 1,
        -y    => 1,
        -x => 20,
        -bg => 'black',
        -fg => 'white',
        -bfg  => 'white',
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

