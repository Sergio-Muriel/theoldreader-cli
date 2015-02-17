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


# Create new instance
sub new
{
    my ($class, %params) = @_;
    my $self = bless { %params }, $class;

    $self->{'cache'} = TheOldReader::Cache->new();

    my $ua = LWP::UserAgent->new;
    $ua->agent("irssi-theoldreader/0.1");
    $self->{'ua'} = $ua;

    croak q('host' is required) unless $self->{'host'};
    return $self;
}

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

# Commong result conversion, parse json
sub json_result()
{
    my ($self, $res) = @_;
    if($res->is_success)
    {
        return from_json($res->content);
    }
}

sub raw_result()
{
    my ($self, $res) = @_;
    if($res->is_success)
    {
        return $res->content;
    }
    return undef;
}


# Auth, check login and fill token
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

# Receive login and fill token if correct
sub auth_result
{
    my ($self, $res) = @_;
    if($res->is_success && $res->content=~ /Auth=(.*)$/)
    {
        $self->{'token'}=$1;
    }
    return $self->{'token'};
}

# Check status
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

# List unread feeds (obvious)
sub unread_feeds()
{
    my ($self) = @_;
    my $list = $self->req(GET($self->{'host'}.TheOldReader::Constants::UNREAD_COUNTS), 'json_result');
    $self->{'cache'}->save_cache('unread_feeds', $list);
    return $list;
}


# Get subscription list(@TODO: hash by labels)
sub subscription_list()
{
    my ($self) = @_;
    if($self->{'subscriptions'})
    {
        return $self->{'subscriptions'};
    }
    $self->req(GET($self->{'host'}.TheOldReader::Constants::SUBSCRIPTION_LIST), 'subscription_list_result');
}

# Get category information for a given id
sub get_category()
{
    my ($self, $id) = @_;
    if(!$self->{'subscriptions'})
    {
        $self->subscription_list();
    }
    return $self->{'subscriptions_refs'}{$id};
}

sub subscription_list_result()
{
    my ($self, $res) = @_;
    if($res->is_success)
    {
        my $data = from_json($res->content);
        if($$data{'subscriptions'})
        {
            my @subscriptions = @{$$data{'subscriptions'}};
            $self->{'subscriptions'} = ();
            $self->{'subscriptions_refs'} = ();
            my $num=0;
            foreach my $item(@subscriptions)
            {
                $$item{'internal'}= ++$num; 
                $self->{'subscriptions'}{$item->{'id'}} = $item;
                $self->{'subscriptions_refs'}{$num} = \$self->{'subscriptions'}{$item->{'id'}};
            }
        }
    }
    return $self->{'subscriptions'};
}

# Fetch user information
sub user_info()
{
    my ($self) = @_;
    return $self->req(GET($self->{'host'}.TheOldReader::Constants::USER_INFO), 'json_result');
}



# Get last items
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
    $self->req(GET($url), 'json_result');
}

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
    $self->req(GET($url), 'json_result');
}


sub contents()
{
    my ($self,@items)=  @_;
    my $url = $self->{'host'}.TheOldReader::Constants::CONTENTS;

    my %form = ();
    foreach(@items)
    {
        push(@{$form{'i'}}, $_);
    }
    my $content = $self->req(POST($url, \%form), 'json_result');
    return $content;
}

sub log()
{
    my ($self, $command) = @_;
    open(WRITE,">>log"),
    print WRITE "API $command\n";
    close WRITE;
}

sub labels()
{
    my ($self)=  @_;

    if(!$self->{'labels'})
    {
        my $list = $self->subscription_list();
        $self->{'labels'} = ();
        foreach my $ref(keys %{$list})
        {
            my @categories = @{$$list{$ref}{'categories'}};
            foreach(@categories)
            {
                $self->{'labels'}{${$_}{'id'}} = ${$_}{'label'};
            }
        }
        $self->{'cache'}->save_cache('labels', $self->{'labels'});
    }
    return $self->{'labels'};
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




1;

__END__

