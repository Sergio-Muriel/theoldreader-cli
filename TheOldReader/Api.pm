package TheOldReader::Api;
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
use TheOldReader::Constants;
use TheOldReader::Cache;

use Data::Dumper;
use URI;
use URI::Escape;
use URI::QueryParam;
use HTTP::Request::Common qw(GET POST);


=head1 TheOldReader API

To use the API:

    use TheOldReader::API;

=cut

=head1 Constructor

    my $read = TheOldReader::Api->new(
       'host' => TheOldReader::Constants::DEFAULT_HOST,
       'token' => $self->{'token'},
    );

=cut

# Create new instance
sub new
{
    my ($class, %params) = @_;
    my $self = bless { %params }, $class;

    my $ua = LWP::UserAgent->new;
    $ua->agent("irssi-theoldreader/0.1");
    $self->{'ua'} = $ua;

    croak q('host' is required) unless $self->{'host'};
    return $self;
}

=head2 Methods 

Private methods

=cut


=head3 req($request,$callback)
=cut
# Create request and run fallback
sub req()
{
    my ($self, $request, $result_func) = @_;

    if ('POST' eq $request->method) {
        $request->uri->scheme('https');
    }
    elsif ('GET' eq $request->method and 'https' ne $request->uri->scheme) {
        $request->uri->scheme('https');
    }
    $request->uri->query_param(ck => time * 1000);
    $request->uri->query_param(client => $self->{'ua'}->agent);

    $request->header(authorization => 'GoogleLogin auth=' . $self->{'token'})
        if $self->{'token'};

    my $res = $self->{'ua'}->request($request);
    return $self->$result_func($res);
}

=head3 json_result($http_result)

Returns the json decoded content, if request is a success
=cut
sub json_result()
{
    my ($self, $res) = @_;
    if($res->is_success)
    {
        return from_json($res->content);
    }
}

=head3 raw_result($http_result)

Returns the content of the http, without any changes
=cut
sub raw_result()
{
    my ($self, $res) = @_;
    if($res->is_success)
    {
        return $res->content;
    }
    else
    {
        $self->log("Error received: ".$res->content);
        return undef;
    }
}


=head3 auth($username, $password)

Returns the token, if auth successfull
=cut
sub auth()
{
    my ($self, $username, $password) = @_;
    $self->{'token'}=undef;


    return $self->req(
        POST($self->{'host'}.TheOldReader::Constants::LOGIN_PATH,
            {
                'client' => 'irssi-theoldreader',
                'accountType' => 'HOSTED_OR_GOOGLE',
                'service' => 'reader',
                'Email' =>$username,
                'Passwd' => $password
            }),
        'auth_result'
    );
}

sub auth_result
{
    my ($self, $res) = @_;
    if($res->is_success && $res->content=~ /Auth=(.*)$/)
    {
        $self->{'token'}=$1;
    }
    return $self->{'token'};
}

=head3 status()

Returns the old reader global status
=cut
sub status()
{
    my ($self) = @_;
    return $self->req(GET($self->{'host'}.TheOldReader::Constants::STATUS), 'status_result');
}


sub status_result()
{
    my ($self, $res) = @_;
    if($res->is_success)
    {
        my $data = from_json($res->content);
        return $$data{'status'} eq 'up';
    }
    return 0;
}

=head3 unread_feeds()

Return unread feed ids
=cut
sub unread_feeds()
{
    my ($self) = @_;
    return $self->req(GET($self->{'host'}.TheOldReader::Constants::UNREAD_COUNTS), 'json_result');
}


=head3 subscription_list()

Return subscription list
=cut
sub subscription_list()
{
    my ($self) = @_;
    if($self->{'subscriptions'})
    {
        return $self->{'subscriptions'};
    }
    return $self->req(GET($self->{'host'}.TheOldReader::Constants::SUBSCRIPTION_LIST), 'subscription_list_result');
}

sub subscription_list_result()
{
    my ($self, $res) = @_;
    if($res->is_success)
    {
        my $data = from_json($res->content);
        if($$data{'subscriptions'})
        {
            return \@{$$data{'subscriptions'}};
        }
    }
    return undef;
}

=head3 user_info()

Return the user info
=cut
sub user_info()
{
    my ($self) = @_;
    return $self->req(GET($self->{'host'}.TheOldReader::Constants::USER_INFO), 'json_result');
}



=head3 last($stream_id, $max_items, $start_from)

Return the last items from $stream_id, starting from $start_from
    $reader->last('user/-/label/blogs',1);

=cut
sub last()
{
    my ($self,$item, $max, $next_id) = @_;

    if(!$max)
    {
        $max=TheOldReader::Constants::DEFAULT_MAX;
    }

    my $url = $self->{'host'}.TheOldReader::Constants::ITEMS;
    $url.= "&s=".$item."&n=$max";
    if($next_id)
    {
        $url.="&c=$next_id";
    }
    return $self->req(GET($url), 'json_result');
}

=head3 unread($stream_id, $max_items, $start_from)

Return the last unread items from $stream_id, starting from $start_from
    $reader->unread('user/-/label/blogs',1);

=cut
sub unread()
{
    my ($self,$item, $max, $next_id) = @_;

    if(!$max)
    {
        $max=TheOldReader::Constants::DEFAULT_MAX;
    }

    my $url = $self->{'host'}.TheOldReader::Constants::ITEMS;
    $url.= "&s=".$item."&n=$max";
    $url.="&xt=".TheOldReader::Constants::STATE_READ;
    if($next_id)
    {
        $url.="&c=$next_id";
    }
    return $self->req(GET($url), 'json_result');
}


=head3 contents(\@ids)

Return the content of ids
    $reader->contents(['xxxxxxx']);

=cut
sub contents()
{
    my ($self,@items)=  @_;
    my $url = $self->{'host'}.TheOldReader::Constants::CONTENTS;

    my %form = ();
    foreach(@items)
    {
        push(@{$form{'i'}}, $_);
    }
    return $self->req(POST($url, \%form), 'json_result');
}


sub labels()
{
    my ($self)=  @_;

    my $url = $self->{'host'}.TheOldReader::Constants::LABELS;
    return $self->req(GET($url), 'json_result');
}

# Get last items
sub mark_read()
{
    my ($self,$ids_ref) = @_;
    my @ids;
    @ids = @{$ids_ref};

    my $url = $self->{'host'}.TheOldReader::Constants::EDIT;
    my %form = ();
    $form{'a'} = TheOldReader::Constants::STATE_READ;
    $form{'i'} = ();
    foreach(@ids)
    {
        push(@{$form{'i'}}, $_);
    }
    return $self->req(POST($url, \%form), 'raw_result');
}

# Mark as liked
sub mark_like()
{
    my ($self,$ids_ref) = @_;
    my @ids;
    @ids = @{$ids_ref};

    my $url = $self->{'host'}.TheOldReader::Constants::EDIT;
    my %form = ();
    $form{'a'} = TheOldReader::Constants::STATE_LIKE;
    $form{'i'} = ();
    foreach(@ids)
    {
        push(@{$form{'i'}}, $_);
    }
    return $self->req(POST($url, \%form), 'raw_result');
}

# UnMark as liked
sub unmark_like()
{
    my ($self,$ids_ref) = @_;
    my @ids;
    @ids = @{$ids_ref};

    my $url = $self->{'host'}.TheOldReader::Constants::EDIT;
    my %form = ();
    $form{'r'} = TheOldReader::Constants::STATE_LIKE;
    $form{'i'} = ();
    foreach(@ids)
    {
        push(@{$form{'i'}}, $_);
    }
    return $self->req(POST($url, \%form), 'raw_result');
}

# Mark as broadcast
sub mark_broadcast()
{
    my ($self,$id, $annotation) = @_;

    my $url = $self->{'host'}.TheOldReader::Constants::EDIT;
    my %form = ();
    $form{'a'} = TheOldReader::Constants::STATE_BROADCAST;
    $form{'i'} = ();
    $form{'annotation'} = $annotation;
    push(@{$form{'i'}}, $id);
    return $self->req(POST($url, \%form), 'raw_result');
}

# UnMark as broadcast
sub unmark_broadcast()
{
    my ($self,$id) = @_;

    my $url = $self->{'host'}.TheOldReader::Constants::EDIT;
    my %form = ();
    $form{'r'} = TheOldReader::Constants::STATE_BROADCAST;
    $form{'i'} = ();
    push(@{$form{'i'}}, $id);

    return $self->req(POST($url, \%form), 'raw_result');
}

# Get last items
sub mark_unread()
{
    my ($self,$ids_ref) = @_;
    my @ids;
    @ids = @{$ids_ref};

    my $url = $self->{'host'}.TheOldReader::Constants::EDIT;
    my %form = ();
    $form{'r'} = TheOldReader::Constants::STATE_READ;
    $form{'i'} = ();
    foreach(@ids)
    {
        push(@{$form{'i'}}, $_);
    }
    return $self->req(POST($url, \%form), 'raw_result');
}

# Mark starred
sub mark_starred()
{
    my ($self,$ids_ref) = @_;
    my @ids;
    @ids = ($ids_ref);

    my $url = $self->{'host'}.TheOldReader::Constants::EDIT;
    my %form = ();
    $form{'a'} = TheOldReader::Constants::STATE_STARRED;
    $form{'i'} = ();
    foreach(@ids)
    {
        push(@{$form{'i'}}, $_);
    }

    return $self->req(POST($url, \%form), 'raw_result');
}

# UnMark starred
sub unmark_starred()
{
    my ($self,$ids_ref) = @_;
    my @ids;
    @ids = ($ids_ref);

    my $url = $self->{'host'}.TheOldReader::Constants::EDIT;
    my %form = ();
    $form{'r'} = TheOldReader::Constants::STATE_STARRED;
    $form{'i'} = ();
    foreach(@ids)
    {
        push(@{$form{'i'}}, $_);
    }
    return $self->req(POST($url, \%form), 'raw_result');
}

sub friends()
{
    my ($self) = @_;

    my $url = $self->{'host'}.TheOldReader::Constants::FRIENDS;
    return $self->req(GET($url), 'json_result');
}

# Get last items
sub unfollow()
{
    my ($self,$id) = @_;

    my $url = $self->{'host'}.TheOldReader::Constants::EDIT_FRIEND;
    my %form = ();
    $form{'action'} = 'removefollowing';
    $form{'u'} = $id;
    return $self->req(POST($url, \%form), 'raw_result');
}

sub follow()
{
    my ($self,$id) = @_;

    my $url = $self->{'host'}.TheOldReader::Constants::EDIT_FRIEND;
    my %form = ();
    $form{'action'} = 'addfollowing';
    $form{'u'} = $id;
    return $self->req(POST($url, \%form), 'raw_result');
}

sub add_feed()
{
    my ($self,$add_feed) = @_;

    my $url = $self->{'host'}.TheOldReader::Constants::ADD_FEED;
    my %form = ();
    $form{'quickadd'} = $add_feed;
    $form{'output'} = 'json';

    return $self->req(POST($url, \%form), 'json_result') || '';
}

sub rename_label()
{
    my ($self,$tag, $newtag) = @_;

    my $url = $self->{'host'}.TheOldReader::Constants::RENAME_TAG;
    my %form = ();
    $form{'s'} = 'user/-/label/'.$tag;
    $form{'dest'} = 'user/-/label/'.$newtag;

    return $self->req(POST($url, \%form), 'raw_result') || '';
}


sub log()
{
    my ($self, $command) = @_;
    open(WRITE,">>log"),
    print WRITE "API $command\n";
    close WRITE;
}


1;

__END__

