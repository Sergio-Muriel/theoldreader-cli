package TheOldReader::Gui;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
use Text::Iconv;

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
use Curses qw(KEY_ENTER);
use Curses::UI::POE;
use Curses::Forms::Dialog::Input;
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
    $self->{'converter'} = Text::Iconv->new("utf8","latin1");

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
    $self->update_list();
}


sub update_loading_list()
{
    my ($self, $id) = @_;

    my %gui_list = %{$self->{'list_data'}};
    my $feed = $self->{'cache'}->load_cache("item tag:google.com,2005:reader_item_".$id);
    my $title="@";
    my $starred="@";
    my $like="@";
    my $broadcast="@";
    if(!$feed)
    {
        $self->log("ERROR: cannot find feed $id");
        return;
    }

    $gui_list{'labels'}{$id} = $self->{'converter'}->convert(" ".$title.$starred.$like.$broadcast." ".$feed->{'title'});
    $self->{'right_container'}->labels($gui_list{'labels'});

    $self->{'cui'}->draw();
}

sub last_status()
{
    my ($self, $id) = @_;

    my $gui_list = $self->{'list_data'};
    my $feed = $self->{'cache'}->load_cache("item tag:google.com,2005:reader_item_".$id);
    my $title;
    my $starred;
    my $like;
    my $broadcast;
    if(!$feed)
    {
        $self->log("ERROR: cannot find feed $id");
        return;
    }

    if(grep(/user\/-\/state\/com.google\/fresh/,@{$feed->{'categories'}}))
    {
        $title="N";
    }
    else
    {
        $title=" ";
    }
    if(grep(/user\/-\/state\/com.google\/starred/,@{$feed->{'categories'}}))
    {
        $starred="*";
    }
    else
    {
        $starred=" ";
    }
    if(grep(/user\/-\/state\/com.google\/like/,@{$feed->{'categories'}}))
    {
        $like="L";
    }
    else
    {
        $like=" ";
    }
    if(grep(/user\/-\/state\/com.google\/broadcast/,@{$feed->{'categories'}}))
    {
        $broadcast="B";
    }
    else
    {
        $broadcast=" ";
    }
    $gui_list->{'labels'}{$id} = $self->{'converter'}->convert(" ".$title.$starred.$like.$broadcast." ".$feed->{'title'});
    $self->{'right_container'}->labels($gui_list->{'labels'});

    $self->{'cui'}->draw();
    $self->update_status("Updated status of $id");
}


sub update_count()
{
    my ($self, @params) = @_;

    $self->update_status("Count updated");

    my $labels = $self->{'labels'};
    if(!$labels)
    {
        $self->log("ERROR: no labels");
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
        $self->log("ERROR: no cache file unread_feeds");
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

    $self->{'left_container'}->labels($labels->{'labels'});
    $self->{'cui'}->draw(1);
    $self->{'counts'} = \%counts;
}

sub update_labels()
{
    my ($self, @params) = @_;

    my $labels = $self->{'cache'}->load_cache('labels');
    my $friends = $self->{'cache'}->load_cache('friends');
    if(!$labels)
    {
        return;
    }

    my %labels = %{$labels};
    my @friends = $friends ? @{$friends} : ();
    my %counts = ();

    my $gui_labels = {};
    $gui_labels = {
        'labels' => {
            TheOldReader::Constants::STATE_ALL => 'All items',
            TheOldReader::Constants::STATE_STARRED=> 'Starred',
            TheOldReader::Constants::STATE_LIKE=> 'Liked',
            TheOldReader::Constants::STATE_BROADCAST=> 'Shared',
            TheOldReader::Constants::STATE_READ=> 'Read',
        },
        'display_labels' => {
            TheOldReader::Constants::STATE_STARRED=> 'Starred',
            TheOldReader::Constants::STATE_LIKE=> 'Liked',
            TheOldReader::Constants::STATE_BROADCAST=> 'Shared'
        },
        'original_labels' => {
            TheOldReader::Constants::STATE_ALL=> 'All items',
            TheOldReader::Constants::STATE_STARRED=> 'Starred',
            TheOldReader::Constants::STATE_LIKE=> 'Liked',
            TheOldReader::Constants::STATE_BROADCAST=> 'Shared',
            TheOldReader::Constants::STATE_READ=> 'Read',
        },
        'values' => [
            TheOldReader::Constants::STATE_ALL,
            TheOldReader::Constants::STATE_STARRED,
            TheOldReader::Constants::STATE_LIKE,
            TheOldReader::Constants::STATE_BROADCAST,
            TheOldReader::Constants::STATE_READ,
        ]
    };

    if($#friends>0)
    {
        $self->log("Add friends ");
        my $key = TheOldReader::Constants::STATE_FRIENDS;
        $gui_labels->{'display_labels'}{$key} = $self->{'converter'}->convert("Friends");
        $gui_labels->{'labels'}{$key} = $self->{'converter'}->convert("Friends");
        $gui_labels->{'original_labels'}{$key} = $self->{'converter'}->convert("Friends");
        push(@{$gui_labels->{'values'}}, $key);
    }

    #foreach my $ref(@friends)
    #{
    #    my $key = $ref->{'stream'};
    #    $gui_labels->{'display_labels'}{$key} = $self->{'converter'}->convert($ref->{'displayName'});
    #    $gui_labels->{'labels'}{$key} = '@-'.$self->{'converter'}->convert($ref->{'displayName'});
    #    $gui_labels->{'original_labels'}{$key} = '@-'.$self->{'converter'}->convert($ref->{'displayName'});
    #
    #    push(@{$gui_labels->{'values'}}, $ref->{'stream'});
    #}

    foreach my $ref(keys %labels)
    {
        $gui_labels->{'display_labels'}{$ref} = $self->{'converter'}->convert($labels->{$ref});
        $gui_labels->{'labels'}{$ref} = "> ".$self->{'converter'}->convert($labels->{$ref});
        $gui_labels->{'original_labels'}{$ref} = "> ".$self->{'converter'}->convert($labels->{$ref});

        push(@{$gui_labels->{'values'}}, $ref);
    }

    $self->{'labels'} = $gui_labels;


    $self->{'left_container'}->values(@{$gui_labels->{'values'}});
    $self->{'left_container'}->labels($gui_labels->{'labels'});

    if(!defined($self->{'left_container'}->get()))
    {
        $self->log("set selected!");
        $self->{'left_container'}->set_selection((0));
    }

    $self->update_status("Labels updated.");
    $self->{'cui'}->draw(1);
}

sub update_status()
{
    my ($self, $text) = @_;
    $self->{'statusbar'}->text($text);
    $self->{'cui'}->draw();
}


sub init
{
    my ($self, @params) = @_;


    # Build gui
    $self->build_gui();
    $self->build_content();
    $self->build_help();
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
                $_[HEAP]->{next_loop_event} = int(time());
                $_[KERNEL]->alarm(loop_event_tick => $_[HEAP]->{next_loop_event});

                $_[HEAP]->{next_count_event} = int(time()) + 1;
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
        -padBottom => 2,
        -y    => 1,
        -bfg  => 'white'
    );

    $self->{'left_container'} = $self->{'container'}->add(
        'left_container',
        'Listbox',
        -width => TheOldReader::Constants::GUI_CATEGORIES_WIDTH,
        -bfg  => 'white',
        -values => [ 'load_more' ],
        -labels => { 'load_more' => ' Loading...'},
        -onchange => sub {
            $self->update_list('clear');
            $self->{'right_container'}->focus();
        },
        -onselchange => sub { $self->left_container_focus(); },
        -onfocus => sub { $self->left_container_focus(); }
    );

    $self->{'right_container'} = $self->{'container'}->add(
        'right_container',
        'Listbox',
        -border => 0,
        -x => TheOldReader::Constants::GUI_CATEGORIES_WIDTH,
        -y => 0,
        -values => [ 'load_more' ],
        -labels => { 'load_more' => ' Loading ...' },
        -bg => 'blue',
        -fg => 'white',
        -onselchange => sub { $self->right_container_onselchange(); },
        -onfocus => sub { $self->right_container_focus(); }
    );


    # HELP Bar
    $self->{'helpbar'} = $self->{'window'}->add(
        'helpbar',
        'Container',
        -y    => $ENV{'LINES'}-2,
        -height => 1,
        -bg => 'red',
        -fg => 'white'
    );

    $self->{'helptext'} = $self->{'helpbar'}->add(
        'helptext',
        'Label',
        -bold => 1,
        -fg => 'yellow',
        -bg => 'blue',
        -bold => 1,
        -width => $ENV{'COLS'},
        -text => ''
    );

    # FOOTER
    $self->{'bottombar'} = $self->{'window'}->add(
        'bottombar',
        'Container',
        -y    => $ENV{'LINES'}-1,
        -height => 1,
        -bg => 'black',
        -fg => 'white'
    );

    $self->{'statusbar'} = $self->{'bottombar'}->add(
        'statusbar',
        'Label',
        -bold => 1,
        -width => $ENV{'COLS'},
        -text => ' Loading...'
    );

    $self->{'bottombar'}->focus();
    $self->{'left_container'}->focus();
    $self->{'right_container'}->draw();
}

sub build_content()
{
    my ($self) = @_;
    $self->log("Building content");

    $self->{'content_container'} = $self->{'window'}->add(
        'content_container',
        'Container',
        -border => 1,
        -height => $ENV{'LINES'} - 3,
        -y    => 1,
        -bg => 'blue',
        -fg => 'white',
        -bfg  => 'white'
    );


    $self->{'content_text'} = $self->{'content_container'}->add(
        'content_text',
        'TextViewer',
        -padleft => 1,
        -padright => 1,
        -vscrollbar => 1,
        -wrapping => 1,
        -focusable => 1,
        -border => 0,
        -x => 0
    );
}
sub build_help()
{
    my ($self) = @_;
    $self->{'help_container'} = $self->{'window'}->add(
        'help_container',
        'Container',
        -border => 1,
        -height => $ENV{'LINES'} - 3,
        -y    => 1,
        -bg => 'black',
        -fg => 'white',
        -bfg  => 'white'
    );
    $self->{'help_text'} = $self->{'help_container'}->add(
        'help_text',
        'TextViewer',
        -padleft => 1,
        -padright => 1,
        -vscrollbar => 1,
        -wrapping => 1,
        -focusable => 1,
        -border => 0,
        -x => 0
    );
    $self->{'help_text'}->text("General key bindings:
?           Display Help
Ctrl+C      Exit
Ctrl+Q      Exit

Help window:
q           Exit this help window

Main window:
q           Exit
u           Update selected label
x           Switch display only unread or all items

Feed list:
Enter       Display item fullscreen
s           Star item
l           Like item
b           Broadcast item (share!)
r           Read item
R           Unread item
o           Open item in the browser
O           Open ALL displayed item in the browser
n           Dsiap

Displaying item:
n           Display next item
p           Display previous item
o           Open item in the browser

");
}

sub run_gui()
{
    my ($self) = @_;
    $self->{'cui'}->mainloop();
}

sub add_background_job()
{
    my ($self, $job, $status_txt) = @_;
    $self->update_status($status_txt);

    $self->{'share'}->add("background_job", $job);
}

sub update_list()
{
    my ($self, $clear, $next_list) = @_;
    if(!$next_list) {
        $next_list="";
    }

    my $id = $self->{'left_container'}->get_active_value();
    if($id eq 'load_more' or $id eq "loading")
    {
        return;
    }

    if($clear and $clear eq 'clear')
    {
        # Clear list
        my $gui_list = {
            'labels' => {
                'load_more' => ' Loading ...',
            },
            'values' => [ 'load_more' ]
        };
        $self->{'right_container'}->values(@{$gui_list->{'values'}});
        $self->{'right_container'}->labels($gui_list->{'labels'});
        $self->{'list_data'} = $gui_list;
    }
    else
    {
        $clear='noclear';
    }

    $self->{'cui'}->draw(1);

    $self->add_background_job("last $clear $id ".($self->{'only_unread'} || "0")." ".$next_list, "Fetching last items from $id");
}

sub display_list()
{
    my ($self, $params) = @_;
    my ($clear, $id) = split(/\s+/, $params);

    my $gui_list = {
        'labels' => {
            'load_more' => ' Loading ...'
        },
        'values' => []
    };
    if($clear ne 'clear' and $self->{'list_data'})
    {
        $gui_list = $self->{'list_data'};
    }
    else
    {
        $self->{'list_data'} = $gui_list;
    }

    $self->{'cat_id'} = $id;

    my $last = $self->{'cache'}->load_cache("last ".$id);
    if(!$last)
    {
        $gui_list->{'labels'}{'load_more'} = '    No items found (error)';
        return;
    }
    $self->{'next_list'} = $$last{'continuation'};
    $gui_list->{'labels'}{'load_more'} = '    [ Select to load more ]';

    my @hash_ids = @{$$last{'itemRefs'}};
    my @new_values= ();
    if(@hash_ids)
    {
        foreach(@hash_ids)
        {
            my $id = $_->{'id'};
            if(!grep(/$id/,@{$gui_list->{'values'}}))
            {
                push(@new_values, $id);
                push(@{$gui_list->{'values'}}, $id);
            }
            $self->last_status($id);
        }
    }
    elsif(@{$gui_list->{'values'}}==0)
    {
        $self->log("Updating $clear");
        $gui_list->{'labels'}{'load_more'} = ' No items found';
    }
    if(!$self->{'next_list'})
    {
        $gui_list->{'labels'}{'load_more'} = '    [ Select to update ]';
    }

    if($clear ne 'clear')
    {
        $self->{'right_container'}->insert_at(0, \@new_values);
    }
    else
    {
        if($self->{'next_list'})
        {
            push(@{$gui_list->{'values'}}, 'load_more');
        }
        $self->{'right_container'}->values(@{$gui_list->{'values'}});
    }

    $self->{'right_container'}->labels($gui_list->{'labels'});
    $self->{'cui'}->draw(1);
}

sub left_container_focus()
{
    my ($self) = @_;
    my $id = $self->{'left_container'}->get_active_value();

    my $text = "?:help  u:update";
    $self->{'helptext'}->text($text);
}

sub right_container_onselchange()
{
    my ($self) = @_;

    # Check if need to load more (last selected)
    my $id = $self->{'right_container'}->get_active_value();
    if($id and $id eq 'load_more')
    {
        if($self->{'next_list'})
        {
            my $gui_list = $self->{'list_data'};
            $gui_list->{'labels'}{'load_more'} = '    [ Loading ...]';
            $self->update_list("noclear",$self->{'next_list'});
        }
        else
        {
            $self->log("No next item id to load next list.");
            $self->update_list("noclear");
        }
    }
}
sub right_container_onchange()
{
    my ($self) = @_;

    my $id = $self->{'right_container'}->get_active_value();
    if($id)
    {
        if($id eq 'load_more' or $id eq "loading")
        {
            $self->update_list("noclear",$self->{'next_list'});
            return $self->close_content();
        }

        # Check if need to load more (last selected)
        $self->{'content_container'}->focus();
        $self->{'content_text'}->draw();
        $self->{'item_idx'} = $self->{'right_container'}->get_active_id();
        $self->display_item($id);
        $self->{'content_text'}->draw();
        $self->{'cui'}->draw();
    }
}
sub right_container_focus()
{
    my ($self) = @_;
    $self->{'helptext'}->text('?:help  x:Display only unread/All  u:Update  s:star/unstar  r:mark read  R:unread l:like/unlike b:share  Enter:read summary  o:open in browser');
}


sub display_help()
{
    my ($self) = @_;
    $self->{'help_container'}->focus();
    $self->{'help_text'}->draw();
    $self->{'cui'}->draw();
}

sub close_help()
{
    my ($self) = @_;
    $self->{'right_container'}->focus();
    $self->{'cui'}->draw();
}


sub display_item()
{
    my ($self,$id) = @_;
    $self->{'item_displayed'}=1;
    if($id eq 'load_more' or $id eq "loading")
    {
        $self->update_list("noclear",$self->{'next_list'});
        return $self->close_content();
    }

    my $item = $self->{'cache'}->load_cache("item tag:google.com,2005:reader_item_".$id);
    $self->log("display $id");
    my $text="";
    if($item)
    {
        $self->add_background_job("mark_read ".$id, "Mark as read");

        # Date
        my ($S,$M,$H,$d,$m,$Y) = localtime($$item{'published'});
        $m += 1;
        $Y += 1900;
        my $dt = sprintf("%04d-%02d-%02d %02d:%02d:%02d", $Y,$m,$d, $H,$M,$S);

        # Labels
        my @labels=();
        foreach(@{$item->{'categories'}})
        {
            if($self->{'labels'}{'display_labels'}{$_})
            {
                push(@labels,$self->{'labels'}{'display_labels'}{$_});
            }
        }

        # Likes
        my @likes=();
        my $more_likes=0;
        foreach(@{$item->{'likingUsers'}})
        {
            if($#likes<2)
            {
                push(@likes,$_->{'displayName'});
            }
            else
            {
                $more_likes=1;
            }
        }
        if($more_likes)
        {
            push(@likes, "... (".$item->{'likingUsersCount'}." users)");
        }

        # Content
        my $content=$$item{'summary'}{'content'};
        my @urls=();
        my @images=();

        my $img=0;
        while($content=~ /(<img([^>]+)>)/g)
        {
            $img++;
            my $original = $1;
            my $origin_attr = $2;

            my ($link) = ($origin_attr =~ /src=['"](.*?)['"]/);

            my ($alt) = ($origin_attr =~ /alt=['"](.*?)['"]/);
            if(!$alt) { $alt=""; }

            $original=~ s/([^\w])/\\$1/g;

            $content =~ s/$original/ $alt \[IMAGE$img\]/g;
            push(@images, $link);
        }

        my $num=0;
        while($content=~ /(<a([^>]+)>(.*?)<\/a>)/g)
        {
            $num++;
            my $original = $1;
            my $title = $3;
            my ($link) = ($2 =~ /href=['"](.*?)['"]/);

            $original=~ s/([^\w])/\\$1/g;

            $content =~ s/$original/$title\[$num\]/g;
            push(@urls, $link);
        }

        # List tags
        while($content =~ /<(ol|li)[^>]*>(.*)?<\/\1>/is)
        {
            $content =~ s/<(ol|li)[^>]*>(.*)?<\/\1>/\t- $2\n/isg;
        }

        # Block tags
        $content =~ s/<br\s*\/?>/\n/g;
        while($content =~ /<(h\d|p|div|ul|table|tr|td|th)[^>]*>(.*)?<\/\1>/is)
        {
            $content =~ s/<(h\d|p|div|ul|table|tr|td|th)[^>]*>(.*)?<\/\1>/$2\n/isg;
        }

        # Inline tags and unclosed block tags
        $content =~ s/<\/?[^>]+>//isg;

        # Get url
        my @canonical = @{$item->{'canonical'}};

        $text ="Feed:\t".$$item{'origin'}{'title'}."\n";
        $text.="Title:\t".$$item{'title'}."\n";
        $text.="Author:\t".$$item{'author'}."\n";
        $text.="Date:\t".$dt."\n";
        $text.="Labels:\t".join(", ",@labels)."\n";
        $text.="Likes:\t".join(", ",@likes)."\n";
        $text.="Url:\t".$canonical[0]{'href'}."\n";
        $text.="\n";
        $text.=$content."\n";
        $text.="\n";
        if(@urls)
        {
            $num=0;
            $text.="Links:\n";
            foreach(@urls)
            {
                $num++;
                $text.="\t[$num]: $_\n";
            }
        }
        if(@images)
        {
            $num=0;
            $text.="Images\n";
            foreach(@images)
            {
                $num++;
                $text.="\t[$num]: $_\n";
            }
        }

    }
    else
    {
        $text="Error getting feed information $id";
    }

    $text = $self->{'converter'}->convert($text);
    $self->{'content_text'}->text($text);
}

sub prev_item()
{
    my ($self,$id) = @_;
    my @items = @{$self->{'right_container'}->values()};
    my $prev = $self->{'item_idx'}-1;
    if($prev>=0 && $items[$prev])
    {
        $self->{'right_container'}->set_selection(($prev));
        $self->display_item($items[$prev]);
        $self->{'item_idx'}= $prev;
    }
}
sub open_item()
{
    my ($self) = @_;
    my @items = @{$self->{'right_container'}->values()};
    my $id;
    if($self->{'item_displayed'})
    {
        $id  = $items[$self->{'item_idx'}];
    }
    else
    {
        $id = $self->{'right_container'}->get_active_value();
    }

    my $item = $self->{'cache'}->load_cache("item tag:google.com,2005:reader_item_".$id);
    if($item)
    {
        my @canonical = @{$item->{'canonical'}};
        open CMD, "| ".($self->{'browser'}||"x-www-browser") ." '".$canonical[0]{'href'}."' 2>/dev/null";
        close CMD;
        $self->right_container_read();
    }
}

sub open_all()
{
    my ($self) = @_;
    my @items = @{$self->{'right_container'}->values()};
    foreach my $id(@items)
    {
        my $item = $self->{'cache'}->load_cache("item tag:google.com,2005:reader_item_".$id);
        if($item)
        {
            my @canonical = @{$item->{'canonical'}};
            open CMD, "| ".($self->{'browser'}||"x-www-browser") ." '".$canonical[0]{'href'}."' 2>/dev/null";
            close CMD;
            $self->right_container_read();
        }
    }
}

sub next_item()
{
    my ($self,$id) = @_;
    my @items = @{$self->{'right_container'}->values()};
    my $next = $self->{'item_idx'}+1;
    if($items[$next])
    {
        $self->{'right_container'}->set_selection(($next));
        $self->display_item($items[$next]);
        $self->{'item_idx'}= $next;
    }

}


# Runned every 1 second to check if there is something from background job to run
sub loop_event()
{
    my ($self, @params) = @_;
    
    my $received = $self->{'share'}->shift('gui_job');
    if($received)
    {
        my ($command, $params)  = ($received=~ /^(\S+)\s*(.*?)$/);
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
    $self->update_list("clear");
}
sub close_content()
{
    my ($self) = @_;
    $self->{'item_displayed'}=0;

    $self->{'item_idx'}=undef;
    $self->{'right_container'}->focus();
    $self->{'cui'}->draw(1);
}

sub right_container_star()
{
    my ($self) = @_;
    my $id = $self->{'right_container'}->get_active_value();
    my $feed = $self->{'cache'}->load_cache("item tag:google.com,2005:reader_item_".$id);

    $self->update_loading_list($id);
    if($feed)
    {
        if(!grep(/user\/-\/state\/com.google\/starred/,@{$feed->{'categories'}}))
        {
            $self->add_background_job("mark_starred ".$feed->{'id'}, "Mark starred");
        }
        else
        {
            $self->add_background_job("unmark_starred ".$feed->{'id'}, "Unmark Starred");
        }
    }
    else
    {
        $self->log("Feed not ready! $id");
    }
}
sub right_container_like()
{
    my ($self) = @_;
    my $id = $self->{'right_container'}->get_active_value();
    my $feed = $self->{'cache'}->load_cache("item tag:google.com,2005:reader_item_".$id);

    $self->update_loading_list($id);
    if($feed)
    {
        if(!grep(/user\/-\/state\/com.google\/like/,@{$feed->{'categories'}}))
        {
            $self->add_background_job("mark_like ".$feed->{'id'}, "Mark liked");
        }
        else
        {
            $self->add_background_job("unmark_like ".$feed->{'id'}, "Unmark liked");
        }
    }
    else
    {
        $self->log("Feed not ready! $id");
    }
}
sub right_container_broadcast()
{
    my ($self) = @_;
    my $id = $self->{'right_container'}->get_active_value();
    my $feed = $self->{'cache'}->load_cache("item tag:google.com,2005:reader_item_".$id);

    $self->update_loading_list($id);
    if($feed)
    {
        if(!grep(/user\/-\/state\/com.google\/broadcast/,@{$feed->{'categories'}}))
        {
            my ($rv, $text) = input('Input Parameter!', BTN_OK | BTN_CANCEL, 'Search String', 20, qw(white blue yellow));
            if(!$rv)
            {
                $self->add_background_job("mark_broadcast ".$feed->{'id'}." $text", "Mark liked");
            }
        }
        else
        {
            $self->add_background_job("unmark_broadcast ".$feed->{'id'}, "Unmark liked");
        }
    }
    else
    {
        $self->log("Feed not ready! $id");
    }
}

sub right_container_read()
{
    my ($self) = @_;
    my $id = $self->{'right_container'}->get_active_value();

    $self->add_background_job("mark_read ".$id, "Mark as read");
    $self->update_loading_list($id);
    $self->goto_next();
}

sub goto_next()
{
    my ($self) = @_;
    my $idx = $self->{'right_container'}{'-ypos'};
    $self->{'right_container'}{'-ypos'} = $idx+1;
    $self->{'cui'}->draw();
}

sub right_container_unread()
{
    my ($self) = @_;
    my $id = $self->{'right_container'}->get_active_value();

    $self->add_background_job("mark_unread ".$id, "Unmark as read");
    $self->update_loading_list($id);
}

sub bind_keys()
{
    my ($self, @params) = @_;
    my $exit_ref = sub {
        $self->exit_dialog();
    };

    $self->{'cui'}->set_binding(sub { $self->display_help(); }, "?");
    $self->{'cui'}->set_binding($exit_ref, "\cC");
    $self->{'cui'}->set_binding($exit_ref, "\cQ");

    $self->{'container'}->set_binding(sub { $self->close_content(); }, "q");
    $self->{'container'}->set_binding(sub { $self->update_list("clear"); }, "u");
    $self->{'container'}->set_binding(sub { $self->switch_unread_all(); }, "x");

    $self->{'right_container'}->set_binding(sub { $self->right_container_onchange(); }, KEY_ENTER);
    $self->{'right_container'}->set_binding(sub { $self->right_container_star(); }, "s");
    $self->{'right_container'}->set_binding(sub { $self->right_container_like(); }, "l");
    $self->{'right_container'}->set_binding(sub { $self->right_container_broadcast(); }, "b");
    $self->{'right_container'}->set_binding(sub { $self->right_container_read(); }, "r");
    $self->{'right_container'}->set_binding(sub { $self->right_container_unread(); }, "R");
    $self->{'right_container'}->set_binding(sub { $self->open_item(); }, "o");
    $self->{'right_container'}->set_binding(sub { $self->open_all(); }, "O");

    $self->{'content_container'}->set_binding(sub { $self->next_item(); }, "n");
    $self->{'content_container'}->set_binding(sub { $self->prev_item(); }, "p");
    $self->{'content_container'}->set_binding(sub { $self->open_item(); }, "o");


    $self->{'help_container'}->set_binding(sub { $self->close_help(); }, "q");


}
sub exit_dialog()
{
    my ($self, @params) = @_;

    my $exit_ref = sub { $self->exit_dialog(); };
    threads->exit();
    $self->{'cui'}->mainloopExit();
    # exit(0);
}

sub output_error()
{
    my ($self, $error) = @_;
    print STDERR $error."\n";
}


1;

__END__

