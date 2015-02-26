package TheOldReader::Cli;

use Exporter;
use Storable;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
use IO::Prompt;
use Locale::gettext;

$VERSION     = 1.00;
@ISA         = qw(Exporter TheOldReader::Config);
@EXPORT      = ();

use strict;
use warnings;
use TheOldReader::Config;
use TheOldReader::Api;
use TheOldReader::Cache;
use Carp qw(croak);
use Data::Dumper;
use POSIX;

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

    my ($dirpath) = (__FILE__ =~ /(.*\/)[^\/]+?$/);
    bindtextdomain("messages", $dirpath."/locale");
    textdomain("messages");

    $self->{'cache'} = TheOldReader::Cache->new();

    $self->{'reader'} = TheOldReader::Api->new(
       'host' => TheOldReader::Constants::DEFAULT_HOST,
       'token' => $self->{'token'},
    );
    return $self;
}

sub help()
{
    my ($self) = @_;
    $self->output_string("Use: $0 [ create_config | unread | last | labels | mark_read | subscription_list | unread_feeds  | watch | mark_like | unmark_like | mark_broadcast | unmark_broadcast | friends | add_feed | rename_label | add_comment ]");
    $self->output_string("");

    $self->output_string(gettext("Available commands:"));
    my @list= (
        "create_config: ".gettext("Prompt for username and password to get auth token"),
        "unread [feed_id]: ".gettext("Display unread items (of the feed or all)"),
        "last [feed_id]: ".gettext("Display last items (of the feed, or all)"),
        "labels: ".gettext("Display labels"),
        "mark_read [item/feed/label]: ".gettext("Mark as read an item"),
        "subscription_list: ".gettext("List of subscribed urls"),
        "unread_feeds ".gettext("List feed names with unread items"),
        "watch ".gettext("Display unread items when they arrive, until CTRl+C is pressed"),
    );
    $self->output_list(@list);
    $self->output_string("");
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
    my $browser = prompt(gettext('Default browser').' [x-www-browser]:') || 'x-www-browser';
    $self->{'token'} = $token;
    $self->{'browser'} = $browser;
    $self->{'max_items_displayed'} = $max_items_displayed;

    $self->save_config();
    $self->output_string(gettext("Configuration file created"));
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

sub subscription_list()
{
    my ($self) = @_;

    my $list =  $self->{'reader'}->subscription_list();
    if(!$list)
    {
        return $self->output_error("Cannot get subscription list. Check out configuration.");
    }
    my @urls = ();
    foreach my $ref(@{$list})
    {
        push(@urls, $ref->{'url'});
    }
    $self->output_string("Feed urls:");
    $self->output_list(@urls);
    $self->{'cache'}->save_cache("subscription_list",\$list);
    return $list;
}

sub unread_feeds()
{
    my ($self) = @_;
    my $list =  $self->{'reader'}->unread_feeds();
    if(!$list)
    {
        return $self->output_error("Cannot get unread feeds. Check out configuration.");
    }
    my $unread_counts =  $$list{'unreadcounts'};
    my @list = ();
    my $subscription_list = $self->subscription_list();
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
        $id= TheOldReader::Constants::STATE_READ;
        $mark_read_id = TheOldReader::Constants::STATE_ALL;
    }
    my $items = $self->{'reader'}->unread($id, $self->{'max_items_displayed'});
    if(!$items)
    {
        return $self->output_error("Cannot get unread items. Check out configuration.");
    }
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



sub labels()
{
    my ($self) = @_;
    my $list =  $self->{'reader'}->labels();
    if(!$list)
    {
        return $self->output_error("Cannot get labels. Check out configuration.");
    }
    $self->output_string("List of labels:");
    my @labels = ();

    foreach my $ref(@{$list->{'tags'}})
    {
        push(@labels, $ref->{'id'});
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
        $id= TheOldReader::Constants::STATE_READ;

    }

    my $items = $self->{'reader'}->last($id, $self->{'max_items_displayed'});
    if(!$items)
    {
        return $self->output_error("Cannot get last items. Check out configuration.");
    }
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
    if(ref($ids_ref) eq 'ARRAY')
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

sub mark_like()
{
    my ($self, @params) = @_;
    my $ids_ref = shift(@params);
    my @ids;
    if(ref($ids_ref) eq 'ARRAY')
    {
        @ids = @{$ids_ref};
    }
    else
    {
        @ids = ($ids_ref);
    }

    my $content = $self->{'reader'}->mark_like(\@ids);
    if($content eq "OK")
    {
        $self->output_string("Feed(s) marked as liked.");
    }
    else
    {
        $self->output_error("Error marking feed(s) as liked.");
    }
}

sub unmark_like()
{
    my ($self, @params) = @_;
    my $ids_ref = shift(@params);
    my @ids;
    if(ref($ids_ref) eq 'ARRAY')
    {
        @ids = @{$ids_ref};
    }
    else
    {
        @ids = ($ids_ref);
    }

    my $content = $self->{'reader'}->unmark_like(\@ids);
    if($content eq "OK")
    {
        $self->output_string("Feed(s) unmarked as liked.");
    }
    else
    {
        $self->output_error("Error unmarking feed(s) as liked.");
    }
}

sub mark_broadcast()
{
    my ($self, @params) = @_;
    my $id = shift(@params);
    my $annotation = shift(@params);

    my $content = $self->{'reader'}->mark_broadcast($id, $annotation);
    if($content eq "OK")
    {
        $self->output_string("Feed(s) marked as broadcast.");
    }
    else
    {
        $self->output_error("Error marking feed(s) as broadcast.");
    }
}

sub unmark_broadcast()
{
    my ($self, @params) = @_;
    my $id = shift(@params);

    my $content = $self->{'reader'}->unmark_broadcast($id);
    if($content eq "OK")
    {
        $self->output_string("Feed(s) unmarked as broadcast.");
    }
    else
    {
        $self->output_error("Error unmarking feed(s) as broadcast.");
    }
}

sub friends()
{
    my ($self, @params) = @_;
    my $id = shift(@params);

    my $content = $self->{'reader'}->friends();
    if(!$content)
    {
        $self->output_error("Cannot get friends list.");
    }
    else
    {
        my @friends = @{$content->{'friends'}};
        my @list= ();
        foreach(@friends)
        {
            push(@list, $_->{'displayName'}." : ".$_->{'stream'});
        }
        $self->output_list(@list);
        $self->{'cache'}->save_cache('friends', $content->{'friends'});
    }
}
sub follow()
{
    my ($self, @params) = @_;
    my $id = shift(@params);

    my $result = $self->{'reader'}->follow($id);
    $self->output_string($result);
}

sub unfollow()
{
    my ($self, @params) = @_;
    my $id = shift(@params);

    my $result = $self->{'reader'}->unfollow($id);
    $self->output_string($result);
}
sub add_feed()
{
    my ($self, @params) = @_;
    my $url = shift(@params);

    my $result = $self->{'reader'}->add_feed($url);
    if($result and !$$result{'error'})
    {
        $self->output_string("Added ".$$result{'streamId'}.": ".$$result{'query'});
    }
    else
    {
        $self->output_error("ERROR: Cannot add feed: ".$$result{'error'});
    }
}
sub rename_label()
{
    my ($self, @params) = @_;
    my $tag = shift(@params);
    my $newtag = shift(@params);

    my $result = $self->{'reader'}->rename_label($tag, $newtag);
    $self->output_string("Renaming label $tag to $newtag: result $result");
}

sub add_comment()
{
    my ($self, @params) = @_;
    my $id = shift(@params);
    my $text = shift(@params);

    my $result = $self->{'reader'}->add_comment($id, $text);
    $self->output_string("Adding comment to $id: result $result");
}
sub edit_feed()
{
    my ($self, @params) = @_;
    my $id = shift(@params);
    my $label = shift(@params);

    my $result = $self->{'reader'}->edit_feed($id, $label);
    $self->output_string("Edit feed $id. Result: $result");
}

sub log()
{
    my ($self, $command) = @_;
    open(WRITE,">>log"),
    print WRITE "GUI: $command\n";
    close WRITE;
}





1;
