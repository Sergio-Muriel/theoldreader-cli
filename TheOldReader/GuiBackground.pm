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
use POSIX qw(strftime);

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
    $self->{'debug'} = $params{'debug'};

    $self->read_config();
    $self->{'share'} = $params{'share'};

    return $self;
}

sub error()
{
    my ($self, $message) = @_;
    print STDERR "Error: $message\n";
}



sub unread_feeds()
{
    my ($self, @params) = @_;
    # Init labels
    my $unread = $self->{'reader'}->unread_feeds();
    if($unread)
    {
        $self->{'cache'}->save_cache("unread_feeds", $unread);
        $self->add_gui_job("update_count");
    }
    else
    {
        $self->add_gui_job("error Cannot fetch unread feeds"); 
    }
}

sub subscription_list()
{
    my ($self, @params) = @_;
    my $subscriptions = $self->{'reader'}->subscription_list();
    if($subscriptions)
    {
        my %labels = ();
        my @labels;
        $self->{'cache'}->save_cache("subscriptions", $subscriptions);
    }
    else
    {
        return $self->add_gui_job("error Cannot get labels.");
    }
    my $friends = $self->{'reader'}->friends();
    if($friends)
    {
        $self->{'cache'}->save_cache("friends", $$friends{'friends'});
    }
    else
    {
        return $self->add_gui_job("error Cannot get friend list.");
    }
    $self->add_gui_job("update_labels");
}

sub labels()
{
    my ($self, @params) = @_;
    my $labels = $self->{'reader'}->labels();
    if($labels)
    {
        $self->{'cache'}->save_cache("labels", $labels->{'tags'});
    }
    else
    {
        return $self->add_gui_job("error Cannot get labels.");
    }
    my $friends = $self->{'reader'}->friends();
    if($friends)
    {
        $self->{'cache'}->save_cache("friends", $$friends{'friends'});
    }
    else
    {
        return $self->add_gui_job("error Cannot get friend list.");
    }
    $self->add_gui_job("update_labels");

}

sub mark_starred()
{
    my ($self, $id) = @_;
    my @ids = ($id);
    my $result = $self->{'reader'}->mark_starred(@ids);
    my $contents = $self->{'reader'}->contents(@ids);
    if($contents)
    {
        foreach(@{$$contents{'items'}})
        {
            $self->{'cache'}->save_cache("item ".$_->{'id'}, $_);
        }
    }
    $id=~ s/tag\:google\.com\,2005\:reader\/item\///g;
    $self->add_gui_job("last_status $id");
    $self->add_gui_job("update_status Marked as starred");
}

sub unmark_starred()
{
    my ($self, $id) = @_;
    my @ids = ($id);
    my $result = $self->{'reader'}->unmark_starred(@ids);
    my $contents = $self->{'reader'}->contents(@ids);
    if($contents)
    {
        foreach(@{$$contents{'items'}})
        {
            $self->{'cache'}->save_cache("item ".$_->{'id'}, $_);
        }
    }
    $id=~ s/tag\:google\.com\,2005\:reader\/item\///g;
    $self->add_gui_job("last_status $id");
    $self->add_gui_job("update_status Unmarked as starred");
}

sub mark_like()
{
    my ($self, $id) = @_;
    my @ids = ($id);
    my $result = $self->{'reader'}->mark_like(\@ids);
    my $contents = $self->{'reader'}->contents(@ids);
    if($contents)
    {
        foreach(@{$$contents{'items'}})
        {
            $self->{'cache'}->save_cache("item ".$_->{'id'}, $_);
        }
    }
    $id=~ s/tag\:google\.com\,2005\:reader\/item\///g;
    $self->add_gui_job("last_status $id");
    $self->add_gui_job("update_status Marked as liked");
}

sub unmark_like()
{
    my ($self, $id) = @_;
    my @ids = ($id);
    my $result = $self->{'reader'}->unmark_like(\@ids);
    my $contents = $self->{'reader'}->contents(@ids);
    if($contents)
    {
        foreach(@{$$contents{'items'}})
        {
            $self->{'cache'}->save_cache("item ".$_->{'id'}, $_);
        }
    }
    $id=~ s/tag\:google\.com\,2005\:reader\/item\///g;
    $self->add_gui_job("last_status $id");
    $self->add_gui_job("update_status Unmarked as liked");
}

sub mark_broadcast()
{
    my ($self, $params) = @_;
    my ($id, $annotation) = ($params =~ /^(\S+)\s+(.*)$/);

    my $result = $self->{'reader'}->mark_broadcast($id, $annotation);
    my $contents = $self->{'reader'}->contents(($id));
    if($contents)
    {
        foreach(@{$$contents{'items'}})
        {
            $self->{'cache'}->save_cache("item ".$_->{'id'}, $_);
        }
    }
    $id=~ s/tag\:google\.com\,2005\:reader\/item\///g;
    $self->add_gui_job("last_status $id");
    $self->add_gui_job("update_status Marked as shared");
}

sub unmark_broadcast()
{
    my ($self, $id) = @_;
    my $result = $self->{'reader'}->unmark_broadcast($id);
    my $contents = $self->{'reader'}->contents(($id));
    if($contents)
    {
        foreach(@{$$contents{'items'}})
        {
            $self->{'cache'}->save_cache("item ".$_->{'id'}, $_);
        }
    }
    $id=~ s/tag\:google\.com\,2005\:reader\/item\///g;
    $self->add_gui_job("last_status $id");
    $self->add_gui_job("update_status Unmarked as shared");
}

sub mark_read()
{
    my ($self, $id) = @_;
    my @ids = ($id);
    my $result = $self->{'reader'}->mark_read(\@ids);
    my $contents = $self->{'reader'}->contents(@ids);
    if($contents)
    {
        foreach(@{$$contents{'items'}})
        {
            $self->{'cache'}->save_cache("item ".$_->{'id'}, $_);
        }
    }
    $self->add_gui_job("last_status $id");
    $self->add_gui_job("update_status Marked as read");
}
sub mark_unread()
{
    my ($self, $id) = @_;
    my @ids = ($id);
    my $result = $self->{'reader'}->mark_unread(\@ids);
    my $contents = $self->{'reader'}->contents(@ids);
    if($contents)
    {
        foreach(@{$$contents{'items'}})
        {
            $self->{'cache'}->save_cache("item ".$_->{'id'}, $_);
        }
    }
    $self->add_gui_job("last_status $id");
    $self->add_gui_job("update_status Unmarked as read");
}

sub unfollow()
{
    my ($self, $id) = @_;
    my $result = $self->{'reader'}->unfollow($id);
    $self->add_gui_job("update_labels");
}
sub follow()
{
    my ($self, $id) = @_;
    my $result = $self->{'reader'}->follow($id);
    $self->add_gui_job("update_labels");
}

sub rename_label()
{
    my ($self, $params) = @_;
    my ($tag, $newtag) = ($params =~ /^__(.*)__ __(.*)__/);
    $self->log("Rename $tag to $newtag");

    $self->{'reader'}->rename_label($tag, $newtag);
    return $self->labels();
}

sub disable_label()
{
    my ($self, $tag) = @_;

    $self->{'reader'}->disable_label($tag);
    return $self->labels();
}

sub add_feed()
{
    my ($self, $params) = @_;
    my ($url,$label) = split(/\s+/,$params);
    $self->log("Add url $url");

    my $result = $self->{'reader'}->add_feed($url);
    if($result and !$$result{'error'})
    {
        my $id = $$result{'streamId'};
        $self->{'reader'}->edit_feed($id,$label);
        return $self->add_gui_job("update_status feed $url added");
        return $self->add_gui_job("update_labels");
    }
    else
    {
        return $self->add_gui_job("error Cannot add $url: ".$$result{'error'});
    }
}


sub last()
{
    my ($self, @params) = @_;
    my $params = shift(@params);

    my ($clear,$id, $only_unread, $next_id) = split(/\s+/,$params);
    if(!$id)
    {
        $id=TheOldReader::Constants::STATE_ALL;
    }
    if(!$next_id)
    {
        $next_id="";
    }

    my $items;
    if($only_unread)
    {
        $items = $self->{'reader'}->unread($id, $self->{'max_items_displayed'}, $next_id);
    }
    else
    {
        $items = $self->{'reader'}->last($id, $self->{'max_items_displayed'}, $next_id);
    }

    if(!$items)
    {
        return $self->add_gui_job("error Cannot get last items. Check out configuration.");
    }
    $self->{'cache'}->save_cache("last $id", $items);

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
    $self->add_gui_job("display_list $clear $id");
    $self->unread_feeds();
}


sub add_gui_job()
{
    my ($self, $job) = @_;
    $self->{'share'}->add("gui_job", $job);
}

sub thread_command()
{
    my ($self, $received) = @_;

    $self->{'cache'} = TheOldReader::Cache->new();
    $self->{'reader'} = TheOldReader::Api->new(
       'host' => TheOldReader::Constants::DEFAULT_HOST,
       'token' => $self->{'token'},
    );
    if($received)
    {
        my ($command, $params)  = ($received=~ /^(\S+)(?:$|\s(.*)$)/);
        if($self->can($command))
        {
            $self->$command($params);
        }
        else
        {
            $self->log("FATAL ERROR: unknown command $command");
        }
    }
    
}

sub thread_init()
{
    my ($self) = @_;

    my $continue=1;
    while($continue)
    {
        my $received;
        $self->log("Waiting for command.") if ($self->{'debug'});
        while($received = $self->{'share'}->shift('background_job'))
        {
            $self->log("Received ".$received) if($self->{'debug'});
            # Close finisehed
            my @joinable = threads->list(threads::joinable);
            foreach(@joinable)
            {
                $_->join();
            }

            my @threadlist = threads->list(threads::running);
            my $was_waiting=0;
            while ($#threadlist>TheOldReader::Constants::MAX_BG_THREADS)
            {
                select(undef,undef,undef,0.5);
                $self->log("Waiting for some threads to close (".$#threadlist.")") if($self->{'debug'});
                @threadlist = threads->list(threads::running);
                $was_waiting=1;
            }
            if($was_waiting)
            {
                $self->log("OK, we can run new thread! (".$#threadlist.")") if($self->{'debug'});
            }

            if($received eq "quit")
            {
                $continue=0;
            }
            else
            {
                threads->create(sub { $self->thread_command($received); });
            }
        }
        sleep(1);
    }

    # Close finisehed
    $self->add_gui_job("quit");
    my @joinable = threads->list();
    foreach(@joinable)
    {
        $_->detach();
    }
}

sub log()
{
    my $date = strftime "%m/%d/%Y %H:%I:%S", localtime;
    my ($self, $command) = @_;
    open(WRITE,">>log"),
    print WRITE "$date BG: $command\n";
    close WRITE;
}

sub output_error()
{
    my ($self, $error) = @_;
    print STDERR $error."\n";
}


1;

__END__

