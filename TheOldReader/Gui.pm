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


sub call_count
{
    my ($self, @params) = @_;
    $self->add_background_job("unread_feeds", "Updating count...");
}

sub update_last()
{
    my ($self, $id) = @_;

    my $last = $self->{'cache'}->load_cache("last ".$id);
    if(!$last)
    {
        return;
    }

    my %gui_labels = (
        'labels' => {},
        'values' => []
    );


    my @hash_ids = @{$$last{'itemRefs'}};
    foreach(@hash_ids)
    {
        my $id = $_->{'id'};
        my $feed = $self->{'cache'}->load_cache("item tag:google.com,2005:reader_item_".$id);
        if(!$feed)
        {
            $self->log("Error fetch catch $id");
        }
        else
        {
            my $title="";
            my $starred="";
            $gui_labels{'labels'}{$id} = $feed->{'title'};

            if(grep(/user\/-\/state\/com.google\/fresh/,@{$feed->{'categories'}}))
            {
                $title="N";
            }
            else
            {
                $title=" ";
            }
            $gui_labels{'labels'}{$id} = " ".$title.$starred." ".$feed->{'title'};
            push(@{$gui_labels{'values'}}, $id);
        }
    }
    $self->{'right_container'}->values($gui_labels{'values'});
    $self->{'right_container'}->labels($gui_labels{'labels'});

    $self->{'container'}->draw();
    $self->{'cui'}->draw(1);
    $self->{'list_data'} = \%gui_labels;
}


sub update_count()
{
    my ($self, @params) = @_;

    $self->{'statusbar'}->text("Count updated");

    my $labels = $self->{'labels'};
    if(!$labels)
    {
        return;
    }
    my %counts= ();
    if($self->{'counts'})
    {
        %counts = %{$self->{'counts'}};
    }

    my $cache_unread_feeds = $self->{'cache'}->load_cache('unread_feeds');
    if(!$cache_unread_feeds)
    {
        return;
    }

    my $update=0;
    foreach my $ref(@{$$cache_unread_feeds{'unreadcounts'}})
    {
        my $id = $$ref{'id'};
        my $count = $$ref{'count'};
        if(!$counts{$id} or $counts{$id} !=$count)
        {
            $counts{$id} = $count;
            $update=1;
        }
    }
    foreach my $ref(keys %{$labels->{'labels'}})
    {
        my $length = length($labels->{'labels'}{$ref});
        if(!$counts{$ref})
        {
            $counts{$ref}=0;
        }
        my $num = " (".$counts{$ref}.")";
        my $spaces = " "x(TheOldReader::Constants::GUI_CATEGORIES_WIDTH-1-length($labels->{'original_labels'}{$ref})-length($num));
        $labels->{'labels'}{$ref} = substr($labels->{'original_labels'}{$ref},0, (TheOldReader::Constants::GUI_CATEGORIES_WIDTH-1)-length($num)).$spaces.$num;
    }

    if($update)
    {
        $self->{'left_container'}->labels($labels->{'labels'});
        $self->{'container'}->draw();
        $self->{'cui'}->draw(1);
        $self->{'counts'} = \%counts;
    }
}

sub update_labels()
{
    my ($self, @params) = @_;

    my $labels = $self->{'cache'}->load_cache('labels');
    if(!$labels)
    {
        return;
    }

    my %labels = %{$labels};
    my %counts = ();

    my %gui_labels = ();
    %gui_labels = (
        'labels' => {
            'user/-/state/com.google/reading-list' => 'All items',
            'user/-/state/com.google/starred' => 'Starred',
            'user/-/state/com.google/like' => 'Liked',
            'user/-/state/com.google/broadcast' => 'Shared',
            'user/-/state/com.google/read' => 'Read',
        },
        'original_labels' => {
            'user/-/state/com.google/reading-list' => 'All items',
            'user/-/state/com.google/starred' => 'Starred',
            'user/-/state/com.google/like' => 'Liked',
            'user/-/state/com.google/broadcast' => 'Shared',
            'user/-/state/com.google/read' => 'Read',
        },
        'values' => [
            'user/-/state/com.google/reading-list',
            'user/-/state/com.google/starred',
            'user/-/state/com.google/like',
            'user/-/state/com.google/broadcast',
            'user/-/state/com.google/read',
        ]
    );

    foreach my $ref(keys %labels)
    {
        $gui_labels{'labels'}{$ref} = "> ".$labels->{$ref};
        $gui_labels{'original_labels'}{$ref} = "> ".$labels->{$ref};

        push(@{$gui_labels{'values'}}, $ref);
    }

    $self->{'labels'} = \%gui_labels;


    $self->{'left_container'}->values($gui_labels{'values'});
    $self->{'left_container'}->labels($gui_labels{'labels'});

    if(!defined($self->{'left_container'}->get()))
    {
        $self->log("set selected!");
        $self->{'left_container'}->set_selection((0));
    }

    $self->{'labels'} = \%gui_labels;
    $self->{'statusbar'}->text("Labels updated.");

    $self->{'container'}->draw();
    $self->{'cui'}->draw(1);

    $self->{'left_data'} = \%gui_labels;
}


sub init
{
    my ($self, @params) = @_;


    # Build gui
    $self->build_gui();
    $self->build_content();
    $self->bind_keys();

    # Run background jobs
    # $self->update_labels();
    $self->add_background_job("labels", "Updating labels...");

    # Loo gui
    $self->run_gui();
}

sub build_gui()
{
    my ($self, @params) = @_;

    $self->{'cui'} = new Curses::UI::POE(
        -clear_on_exit => 1,
        -color_support => 1,
        inline_states => {
            _start => sub {
                $_[HEAP]->{next_loop_event} = int(time()) + 1;
                $_[KERNEL]->alarm(loop_event_tick => $_[HEAP]->{next_loop_event});

                $_[HEAP]->{next_count_event} = int(time()) + 3;
                $_[KERNEL]->alarm(count_event_tick => $_[HEAP]->{next_count_event});
            },

            loop_event_tick => sub{
                $self->loop_event();
                $_[HEAP]->{next_loop_event}++;
                $_[KERNEL]->alarm(loop_event_tick => $_[HEAP]->{next_loop_event});
            },

            count_event_tick => sub{
                $self->call_count();
                $_[HEAP]->{next_count_event}+=TheOldReader::Constants::GUI_UPDATE;
                $_[KERNEL]->alarm(count_event_tick => $_[HEAP]->{next_count_event});
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
        -height => 1,
        -bg => 'blue',
        -fg => 'white'
    );

    $self->{'toptext'} = $self->{'topbar'}->add(
        'toptext',
        'Label',
        -bold => 1,
        -text => 'The Old Reader - GUI'
    );


    $self->{'container'} = $self->{'window'}->add(
        'container',
        'Container',
        -border => 1,
        -height => $ENV{'LINES'} - 3,
        -y    => 1,
        -bfg  => 'white'
    );

    $self->{'left_container'} = $self->{'container'}->add(
        'left_container',
        'Listbox',
        -width => TheOldReader::Constants::GUI_CATEGORIES_WIDTH,
        -bfg  => 'white',
        -values => [ 1 ],
        -labels => { 1 => 'Loading...'},
        -onchange => sub {
            $self->update_list();
            $self->{'right_container'}->focus();
        },
    );

    $self->{'right_container'} = $self->{'container'}->add(
        'right_container',
        'Listbox',
        -border => 0,
        -x => TheOldReader::Constants::GUI_CATEGORIES_WIDTH,
        -y => 0,
        -values => [ 1 ],
        -labels => { 1 => '' },
        -bg => 'blue',
        -fg => 'white',
        -onselchange => sub { $self->right_container_onselchange(); },
        -onchange => sub { $self->right_container_onchange(); }
    );


    # HELP Bar
    $self->{'helpbar'} = $self->{'window'}->add(
        'helpbar',
        'Container',
        -width => $ENV{'COLS'},
        -y    => $ENV{'LINES'}-2,
        -height => 1,
        -bg => 'red',
        -fg => 'white'
    );

    $self->{'helptext'} = $self->{'helpbar'}->add(
        'helptext',
        'Label',
        -width => $ENV{'COLS'},
        -bold => 1,
        -fg => 'yellow',
        -bg => 'blue',
        -text => 'x:Display only unread/All  u:Update'
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
        'statusbar',
        'Label',
        -width => $ENV{'COLS'},
        -bold => 1,
        -text => 'Loading...'
    );

    $self->{'bottombar'}->focus();
    $self->{'left_container'}->focus();
    $self->{'right_container'}->draw();
}

sub build_content()
{
    my ($self) = @_;
    $self->log("Building content");

    $self->{'content'} = $self->{'cui'}->add(
        'content', 'Window',
    );
    
    $self->{'content_topbar'} = $self->{'content'}->add(
        'content_topbar',
        'Container',
        -y    => 0,
        -height => 1,
        -bg => 'blue',
        -fg => 'white'
    );

    $self->{'content_top'} = $self->{'content_topbar'}->add(
        'content_top',
        'Label',
        -bold => 1,
        -text => 'The Old Reader - Content of ...'
    );


    $self->{'content'} = $self->{'content'}->add(
        'content_text',
        'TextViewer',
        -focusable => 1,
        -border => 0,
        -x => 0,
        -y => 1,
        -height => $ENV{'LINES'} - 3,
        -text => 'bla bla bla',
        -bg => 'blue',
        -fg => 'white',
        -text => 'My content'
    );
}

sub run_gui()
{
    my ($self) = @_;
    $self->{'cui'}->mainloop();
}

sub add_background_job()
{
    my ($self, $job, $status_txt) = @_;
    $self->{'statusbar'}->text($status_txt);

    $self->{'share'}->add("background_job", $job);
}

sub update_list()
{
    my ($self, $id) = @_;

    if(!$id)
    {
        $id = $self->{'left_container'}->get_active_value();
    }

    # Clear list
    my %gui_labels = (
        'labels' => {
            1 => ' Loading ...',
        },
        'values' => [ 1]
    );
    $self->{'right_container'}->values($gui_labels{'values'});
    $self->{'right_container'}->labels($gui_labels{'labels'});

    $self->{'list_data'} = \%gui_labels;
    $self->{'container'}->draw();
    $self->{'cui'}->draw(1);

    $self->log("call last $id");
    $self->add_background_job("last $id ".$self->{'only_unread'}, "Fetching last items from $id");

}

sub right_container_onselchange()
{
    my ($self) = @_;

    # Check if need to load more (last selected)
    my @items = @{$self->{'right_container'}->values()};
    if($#items>1 && $#items == $self->{'right_container'}{'-ypos'})
    {
        $self->log("LAST SELECTED!");
    }
}
sub right_container_onchange()
{
    my ($self) = @_;

    # Check if need to load more (last selected)
    $self->{'content'}->draw();
    $self->{'content'}->focus();
}


# Runned every 1 second to check if there is something from background job to run
sub loop_event()
{
    my ($self, @params) = @_;
    
    my $received = $self->{'share'}->shift('gui_job');
    if($received)
    {
        my ($command, $params)  = ($received=~ /^(\S+)\s*(\S*?)$/);
        if($command)
        {
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
}

sub log()
{
    my ($self, $command) = @_;
    open(WRITE,">>log"),
    print WRITE "GUI: $command\n";
    close WRITE;
}

sub switch_unread_all()
{
    my ($self) = @_;
    $self->{'only_unread'} = !$self->{'only_unread'};
    $self->save_config();
    $self->update_list();
}
sub close_content()
{
    my ($self) = @_;
    $self->{'window'}->focus();
    $self->{'window'}->draw();
    $self->{'cui'}->draw(1);
}

sub bind_keys()
{
    my ($self, @params) = @_;
    my $exit_ref = sub {
        $self->exit_dialog();
    };

    $self->{'window'}->set_binding(sub { $self->update_list(); }, "u");
    $self->{'window'}->set_binding(sub { $self->switch_unread_all(); }, "x");

    $self->{'content'}->set_binding(sub { $self->close_content(); }, "q");

    $self->{'window'}->set_binding($exit_ref, "q");
    $self->{'cui'}->set_binding($exit_ref, "\cC");
    $self->{'cui'}->set_binding($exit_ref, "\cQ");
}
sub exit_dialog()
{
    my ($self, @params) = @_;

    my $exit_ref = sub { $self->exit_dialog(); };
    threads->exit();
    $self->{'cui'}->mainloopExit();
    # exit(0);
}


1;

__END__

