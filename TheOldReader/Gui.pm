package TheOldReader::Gui;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = ();

use strict;
use warnings;
use LWP::UserAgent;
use JSON;
use Carp qw(croak);
use TheOldReader::Api;
use TheOldReader::Constants;

use Curses::UI;

use Data::Dumper;

# Create new instance
sub new
{
    my ($class, %params) = @_;
    my $self = bless { %params }, $class;

    return $self;
}

sub loop
{
    my ($self, @params) = @_;
    $self->{'cui'} =new Curses::UI( -color_support => 1 );

    my $exit_ref = sub { $self->exit_dialog(); };
    my @menu = (
        { -label => 'File', 
            -submenu => [
                { -label => 'Exit', -value => $exit_ref  }
            ]
        },
    );
    my $menu = $self->{'cui'}->add(
        'menu','Menubar', 
        -menu => \@menu,
        -fg  => "blue",
    );

    my $win1 = $self->{'cui'}->add(
        'win1', 'Window',
        -border => 1,
        -y    => 1,
        -bg    => 'blue',
        -fg    => 'white',
        -bfg  => 'white',
    );

    $self->{'cui'}->mainloop();
}
sub exit_dialog()
{
    exit(0);
}


1;

__END__

