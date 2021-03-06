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

    # Default values
    $self->{'token'}="";
    $self->{'max_items_displayed'}=TheOldReader::Constants::DEFAULT_MAX;
    $self->{'only_unread'}=1;
    $self->{'labels_unread'}=1;
    $self->{'display_feeds'}="";
    $self->{'refresh_rate'}=TheOldReader::Constants::DEFAULT_REFRESH_RATE;
    $self->{'browser'}='x-www-browser';
    $self->{'unread_desktop_notification'}=1;
    $self->{'triggers'} = ();
    $self->{'config_comments'} = ();


    open(CONFIG, $self->{'config'});
    while(<CONFIG>)
    {
        if(/^token:(.*)$/) { $self->{'token'}=$1; }
        elsif(/^max_items_displayed:(\d+)$/) {  $self->{'max_items_displayed'}=$1; }
        elsif(/^only_unread:(\d*)$/) {  $self->{'only_unread'}=$1; }
        elsif(/^labels_unread:(\d*)$/){ $self->{'labels_unread'}=$1; }
        elsif(/^display_feeds:(\d*)$/){ $self->{'display_feeds'}=$1; }
        elsif(/^refresh_rate:(\d*)$/) { $self->{'refresh_rate'}=$1; }
        elsif(/^browser:(.*)$/) { $self->{'browser'}=$1; }
        elsif(/^unread_desktop_notification:(.*)$/) { $self->{'unread_desktop_notification'}=$1; }
        elsif(/^trigger:(.*?)$/) {
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
        }
        else
        {
            push(@{$self->{'config_comments'}}, $_);
        }
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

    if(defined($self->{'unread_desktop_notification'}))
    {
        print WRITE "unread_desktop_notification:".$self->{'unread_desktop_notification'}."\n";
    }
    else
    {
        print WRITE "unread_desktop_notification:1\n";
    }

    if(defined($self->{'triggers'}))
    {
        foreach my $trigger(@{$self->{'triggers'}})
        {
            print WRITE "trigger:".$$trigger{'raw'}."\n";
        }
    }
    foreach(@{$self->{'config_comments'}})
    {
        print WRITE $_;
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
    my $browser = prompt(gettext('Default browser').' [x-www-browser]:');
    if($browser eq '')
    {
        $browser = 'x-www-browser';
    }

    my $refresh_rate="";
    while($refresh_rate !~ /^\d+/)
    {
        $refresh_rate = prompt(gettext('Refresh rate').' ['.TheOldReader::Constants::DEFAULT_REFRESH_RATE.']:');
        if($refresh_rate eq '')
        {
            $refresh_rate = TheOldReader::Constants::DEFAULT_REFRESH_RATE;
        }
    }

    my $labels_unread="";
    while($labels_unread !~ /^[YN]/i)
    {
        $labels_unread = prompt(gettext('Display labels with no unread items').' [Y/n]:');
        if($labels_unread eq '')
        {
            $labels_unread = "Y";
        }
    }
    $labels_unread = ($labels_unread =~ /y/i) ? 1 : 0;

    my $unread_desktop_notification="";
    while($unread_desktop_notification !~ /^[YN]/i)
    {
        $unread_desktop_notification = prompt(gettext('Display unread desktop notifications').' [Y/n]:');
        if($unread_desktop_notification eq '')
        {
            $unread_desktop_notification = "Y";
        }
    }
    $unread_desktop_notification = ($unread_desktop_notification =~ /y/i) ? 1 : 0;

    $self->{'token'} = $token;
    $self->{'browser'} = $browser;
    $self->{'refresh_rate'} = $refresh_rate;
    $self->{'labels_unread'} = $labels_unread;
    $self->{'max_items_displayed'} = $max_items_displayed;
    $self->{'unread_desktop_notification'} = $unread_desktop_notification;

    $self->save_config();
    $self->output_string(gettext("Configuration file created"));
}


1;
