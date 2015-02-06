use threads;
use threads::shared;

package TheOldReader::GuiShared; {
    use threads::shared qw(share is_shared shared_clone);
    use Scalar::Util qw(reftype blessed);

    # Constructor
    sub new
    {
        my $class = shift;
        share(my %self);

        # Add arguments to object hash
        while (my $tag = shift) {
            if (!@_) {
                require Carp;
                Carp::croak("Missing value for '$tag'");
            }
            $self{$tag} = shared_clone(shift);
        }

        return (bless(\%self, $class));
    }

    # Adds fields to a shared object
    sub set
    {
        my ($self, $tag, $value) = @_;
        lock($self);
        $self->{$tag} = shared_clone($value);
    }

    sub shift()
    {
        my ($self, $tag, $value) = @_;
        if(!$self->{$tag})
        {
            $self->{$tag} = ();
        }
        shift(@{$self->{$tag}});
    }

    sub add
    {
        my ($self, $tag, $value) = @_;
        if(!$self->{$tag})
        {
            $self->{$tag} = ();
        }
        push(@{$self->{$tag}}, $value);
    }
}

1;
