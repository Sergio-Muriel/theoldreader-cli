package TheOldReader::Cli;

use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
use Data::Dumper;
use IO::Prompt;

$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = ();

use strict;
use warnings;
use TheOldReader::Api;
use TheOldReader::Gui;
use Carp qw(croak);
use Data::Dumper;

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

sub help()
{
    my ($self) = @_;
    $self->output_string("Use: $0 [ create_config | unread | last | labels | mark_read | subscription_list | unread_feeds  | watch ]");
    $self->output_string("");

    $self->output_string("Available commands:");
    my @list= (
        "create_config\t\tPrompt for username and password to get auth token",
        "unread [feed_id]:\tDisplay unread items (of the feed or all)",
        "last [feed_id]:\tDisplay last items (of the feed, or all)",
        "labels:\tDisplay labels",
        "mark_read [item/feed/label]:\tMark as read an item",
        "subscription_list:\tList of subscribed urls",
        "unread_feeds\tList feed names with unread items",
        "watch\tDisplay unread items when they arrive, until CTRl+C is pressed",
    );
    $self->output_list(@list);
    $self->output_string("");
}

sub create_config()
{
    my ($self) = @_;
    $self->output_string("");
    $self->output_string("Creating configuration:");

    my $username = prompt('Username: ');
    my $password = prompt('Password: ', -e => '*');

    $self->{'reader'} = TheOldReader::Api->new(
       'host' => TheOldReader::Constants::DEFAULT_HOST
    );
    my $token = $self->{'reader'}->auth($username, $password);
    if(!$token)
    {
        return $self->output_error("Error: invalid username / password.");
    }

    my $max_items_displayed = prompt('Max items displayed: ');

    open(WRITE, ">".$self->{'config'});
    print WRITE "token:$token\n";
    print WRITE "max_items_displayed:$max_items_displayed\n";
    close WRITE;
    $self->output_string("File ".$self->{'config'}." created.");
}

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
    }
    close(CONFIG);
}

sub output_list()
{
    my ($self, @list) = @_;
    print join("\n",
        map(" - $_ ", @list))."\n";
}

sub output_error()
{
    my ($self, $error) = @_;
    print STDERR $error."\n";
}

sub output_string()
{
    my ($self, $string) = @_;
    print $string."\n";
}

sub unread_feeds()
{
    my ($self) = @_;
    my $list =  $self->{'reader'}->unread_feeds();
    my $unread_counts =  $$list{'unreadcounts'};
    my @list = ();

    my $subscription_list = $self->{'reader'}->subscription_list();
    foreach my $ref(@{$unread_counts})
    {
        my $id = $$ref{'id'};
        my $count = $$ref{'count'};

        if($count>0 && $$subscription_list{$id})
        {
            my $item = $$subscription_list{$id};
            push(@list, $$item{'id'}." : ".$$item{'title'}." ($count)");
        }
    }
    $self->output_string("Unread items:");
    $self->output_list(@list);
}

sub display_feed
{
    my ($self, $feed) = @_;
    my %feed = %{$feed};

    $self->output_string($feed{'id'});
    $self->output_string($feed{'title'});
    $self->output_string($feed{'canonical'}[0]{'href'});

    my $content = $feed{'summary'}{'content'};
    #$content=~ s/<[^>]+>//g;
    #$self->output_string("SUMMARY: $content");

    $self->output_string("");
}

sub unread()
{
    my ($self, @params) = @_;
    my $id = shift(@params);
    my $mark_read_id = $id;
    if(!$id)
    {
        $id="user/-/state/com.google/read";
        $mark_read_id ="user/-/state/com.google/reading-list";
    }
    my $items = $self->{'reader'}->unread($id, $self->{'max_items_displayed'});
    my @hash_ids = @{$$items{'itemRefs'}};
    my @ids = ();
    foreach(@hash_ids)
    {
        push(@ids, ${$_}{'id'});
    }
    my $contents = $self->{'reader'}->contents(@ids);
    if($$contents{'items'})
    {
        foreach(@{$$contents{'items'}})
        {
            $self->display_feed($_);
        }
        return $self->ask_mark_read(\@ids);
    }
    return 0;
}

sub ask_mark_read()
{
    my ($self, @params) = @_;
    my $ids_ref = shift(@params);
    my @ids = @{$ids_ref};

    my $mark_read;
    
    do 
    {
        $mark_read = prompt('Mark '.@{$ids_ref}.' items as read? [O/n]: ');
    } while ($mark_read !~ /^[On]?$/i);

    if($mark_read=~ /^O?$/i)
    {
        return $self->mark_read($ids_ref);
    }
}


sub subscription_list()
{
    my ($self) = @_;

    my $list =  $self->{'reader'}->subscription_list();
    my @urls = ();
    foreach my $ref(keys %{$list})
    {
        push(@urls, $$list{$ref}{'url'});
    }
    $self->output_string("Feed urls:");
    $self->output_list(@urls);
}

sub labels()
{
    my ($self) = @_;
    my $list =  $self->{'reader'}->labels();
    $self->output_string("List of labels:");
    my @labels = ();

    foreach my $ref(keys %{$list})
    {
        push(@labels, "$ref : ".$$list{$ref});
    }
    $self->output_list(@labels);
    $self->output_string("");
}

sub last()
{
    my ($self, @params) = @_;
    my $id = shift(@params);
    if(!$id)
    {
        $id="user/-/state/com.google/read";

    }

    my $items = $self->{'reader'}->last($id, $self->{'max_items_displayed'});
    my @hash_ids = @{$$items{'itemRefs'}};
    my @ids = ();
    foreach(@hash_ids)
    {
        push(@ids, ${$_}{'id'});
    }
    my $contents = $self->{'reader'}->contents(@ids);
    if($$contents{'items'})
    {
        foreach(@{$$contents{'items'}})
        {
            $self->display_feed($_);
        }
    }
}

sub mark_read()
{
    my ($self, @params) = @_;
    my $ids_ref = shift(@params);
    my @ids;
    if(ref($ids_ref) eq 'Array')
    {
        @ids = @{$ids_ref};
    }
    else
    {
        @ids = ($ids_ref);
    }

    my $content = $self->{'reader'}->mark_read($ids_ref);
    if($content eq "OK")
    {
        $self->output_string("Feed(s) marked as read.");
    }
    else
    {
        $self->output_error("Error marking feed(s) as read.");
    }
}

sub watch()
{
    my ($self, @params) = @_;
    while(1)
    {
        if(!$self->unread())
        {
            sleep(TheOldReader::Constants::WAIT_WATCH);
        }
    }
}

sub gui
{
    my ($self, @params) = @_;
    $self->{'gui'} = new TheOldReader::Gui();
    $self->{'gui'}->loop();
}

1;
