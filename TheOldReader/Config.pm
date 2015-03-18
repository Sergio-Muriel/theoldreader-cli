package TheOldReader::Config;

use Exporter;
use Storable;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
use IO::Prompt;
use TheOldReader::Constants;
use Locale::gettext;

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

    $self->{'triggers'} = ();

    open(CONFIG, $self->{'config'});
    while(<CONFIG>)
    {
        /^token:(.*)$/ and $self->{'token'}=$1;
        /^max_items_displayed:(\d+)$/ and $self->{'max_items_displayed'}=$1;
        /^only_unread:(\d*)$/ and $self->{'only_unread'}=$1;
        /^labels_unread:(\d*)$/ and $self->{'labels_unread'}=$1;
        /^display_feeds:(\d*)$/ and $self->{'display_feeds'}=$1;
        /^refresh_rate:(\d*)$/ and $self->{'refresh_rate'}=$1;
        /^browser:(.*)$/ and $self->{'browser'}=$1;
        /^trigger:(.*?)$/ and do {
            my %trigger = ();
            $trigger{'raw'} = $1;
            $trigger{'check'} = [];
            $trigger{'run'} = [];
            if($trigger{'raw'} =~ /^"(.*?)","(.*?)"$/)
            {
                my ($checks,$runs) = ($1,$2);
                push(@{$trigger{'check'}}, split(/[=,]/, $checks));
                push(@{$trigger{'run'}}, split(/[=,]/, $runs));
            }
            push(@{$self->{'triggers'}}, \%trigger);
        };
    }
    close(CONFIG);
}
sub save_config()
{
    my ($self) = @_;
    open(WRITE, ">".$self->{'config'});
    print WRITE "token:".$self->{'token'}."\n";
    print WRITE "max_items_displayed:".$self->{'max_items_displayed'}."\n";

    if(defined($self->{'display_feeds'}))
    {
        print WRITE "display_feeds:".$self->{'display_feeds'}."\n";
    }
    else
    {
        print WRITE "display_feeds:0\n";
    }
    if(defined($self->{'only_unread'}))
    {
        print WRITE "only_unread:".$self->{'only_unread'}."\n";
    }
    else
    {
        print WRITE "only_unread:1\n";
    }
    if(defined($self->{'labels_unread'}))
    {
        print WRITE "labels_unread:".$self->{'labels_unread'}."\n";
    }
    else
    {
        print WRITE "labels_unread:1\n";
    }

    if(defined($self->{'browser'}))
    {
        print WRITE "browser:".$self->{'browser'}."\n";
    }
    else
    {
        print WRITE "browser:x-www-browser\n";
    }
    if(defined($self->{'refresh_rate'}))
    {
        print WRITE "refresh_rate:".$self->{'refresh_rate'}."\n";
    }
    else
    {
        print WRITE "refresh_rate:".TheOldReader::Constants::DEFAULT_REFRESH_RATE."\n";
    }
    if(defined($self->{'triggers'}))
    {
        foreach my $trigger(@{$self->{'triggers'}})
        {
            print WRITE "trigger:".$$trigger{'raw'}."\n";
        }
    }
    else
    {
        print WRITE "refresh_rate:".TheOldReader::Constants::DEFAULT_REFRESH_RATE."\n";
    }
    close WRITE;
}

sub create_config()
{
    my ($self) = @_;
    $self->output_string("");
    $self->output_string(gettext("Creating configuration:"));

    my $username = prompt(gettext('Email').': ');
    my $password = prompt(gettext('Password').': ', -e => '*');

    $self->{'reader'} = TheOldReader::Api->new(
       'host' => TheOldReader::Constants::DEFAULT_HOST
    );
    my $token = $self->{'reader'}->auth($username, $password);
    if(!$token)
    {
        return $self->output_error(gettext("Error: invalid username / password."));
    }

    my $max_items_displayed = 20;
    my $browser = prompt(gettext('Default browser').' [x-www-browser]:') | 'x-www-browser';

    my $refresh_rate="";
    while($refresh_rate !~ /^\d+/)
    {
        $refresh_rate = prompt(gettext('Refresh rate').' ['.TheOldReader::Constants::DEFAULT_REFRESH_RATE.']:') | TheOldReader::Constants::DEFAULT_REFRESH_RATE;
    }

    my $labels_unread="";
    while($labels_unread !~ /^[YN]/i)
    {
        $labels_unread = prompt(gettext('Display labels with no unread items').' [Y/n]:') | 'Y';
    }
    $labels_unread = ($labels_unread =~ /y/i) ? 1 : 0;

    $self->{'token'} = $token;
    $self->{'browser'} = $browser;
    $self->{'refresh_rate'} = $refresh_rate;
    $self->{'labels_unread'} = $labels_unread;
    $self->{'max_items_displayed'} = $max_items_displayed;

    $self->save_config();
    $self->output_string(gettext("Configuration file created"));
}


1;
