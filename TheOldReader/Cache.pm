package TheOldReader::Cache;

use Exporter;
use Storable;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
use IO::Prompt;
use TheOldReader::Constants;
use TheOldReader::Cache;

$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = ();

use strict;
use warnings;
use Carp qw(croak);
use Data::Dumper;

sub new
{
    my ($class, %params) = @_;
    my $self = bless { %params }, $class;

    $self->{'dir'} = TheOldReader::Constants::CACHE_DIR;
    if(!-d $self->{'dir'})
    {
        mkdir($self->{'dir'});
    }

    return $self;
}

sub clean()
{
    my ($self) = @_;
    if(-d $self->{'dir'})
    {
        opendir(my $dh, $self->{'dir'});
        my @dots = grep { /^(item|last)/ && -f $self->{'dir'}."/$_" } readdir($dh);
        foreach my $file(@dots)
        {
            if(-M $self->{'dir'}."/$file" > TheOldReader::Constants::CACHE_DELETE_DAYS)
            {
                if(!unlink($self->{'dir'}."/$file"))
                {
                    $self->log("Error deleting cache file: ".$self->{'dir'}."/$file");
                }
            }
        }
    }
}

sub save_cache()
{
    my ($self,$name,$hash_ref) = @_;

    $name =~ s/\//_/g;

    store($hash_ref, $self->{'dir'}.$name);
}
sub check_cache()
{
    my ($self,$name) = @_;
    $name =~ s/\//_/g;
    return(-f $self->{'dir'}.$name);
}

sub load_cache()
{
    my ($self,$name) = @_;

    $name =~ s/\//_/g;

    if(-f $self->{'dir'}.$name)
    {
        return retrieve($self->{'dir'}.$name);
    }
    return undef;
}

sub log()
{
    my ($self, $command) = @_;
    open(WRITE,">>log"),
    print WRITE "CACHE $command\n";
    close WRITE;
}

1;
