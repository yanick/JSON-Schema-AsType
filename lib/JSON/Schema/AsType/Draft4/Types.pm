package JSON::Schema::AsType::Draft4::Types;

use strict;
use warnings;

use Type::Utils -all;
use Types::Standard qw/ 
    Str StrictNum HashRef ArrayRef 
    Int
/;

use Type::Library
    -base,
    -declare => qw( 
        Minimum
        ExclusiveMinimum
        Maximum
        ExclusiveMaximum
        MinLength
        MultipleOf
        MaxItems
        MinItems

        Null
        Boolean
        Array
        Object
        String
        Integer
        Pattern
        Number

        Required

        Not

        MaxProperties
        MinProperties

        OneOf
    );

use List::MoreUtils qw/ all /;

declare OneOf,
    constraint_generator => sub {
        my @types = @_;
        sub {
            my $v = $_;
            1 == grep { $_->check($v) } @types;
        }
    };

declare MaxProperties,
    constraint_generator => sub {
        my $nbr = shift;
        sub { !Object->check($_) or $nbr >= keys %$_; },
    };

declare MinProperties,
    constraint_generator => sub {
        my $nbr = shift;
        sub { !Object->check($_) or $nbr <= keys %$_; },
    };

declare Not,
    constraint_generator => sub {
        my $type = shift;
        sub { not $type->check($_) },
    };

declare String => as Str & ~StrictNum;

# ~Str or ~String?
declare Pattern,
    constraint_generator => sub {
        my $regex = shift;
        sub { !String->check($_) or /$regex/ },
    };


declare Object => as HashRef ,where sub { ref eq 'HASH' };

declare Required,
    as Object,
    constraint_generator => sub {
        my @keys = @_;
        sub {
            my $obj = $_;
            all { exists $obj->{$_} } @keys;
        }
    };

declare Array => as ArrayRef;

declare Boolean => where sub { ref =~ /JSON/ };

declare Number => as StrictNum & ~Boolean;

declare Integer => as Int & ~Boolean;

declare Null => where sub { not defined };

declare 'MaxItems',
    constraint_generator => sub {
        my $max = shift;

        return sub {
            ref ne 'ARRAY' or @$_ <= $max;
        };
    };

declare 'MinItems',
    constraint_generator => sub {
        my $min = shift;

        return sub {
            ref ne 'ARRAY' or @$_ >= $min;
        };
    };

declare 'MultipleOf',
    constraint_generator => sub {
        my $num =shift;

        return sub {
            !StrictNum->check($_)
                or ($_ / $num) !~ /\./;
        }
    };

declare 'MinLength',
    constraint_generator => sub {
        my $min =shift;

        return sub {
            !Str->check($_)
            or StrictNum->check($_)
            or $min <= length
        }
    };

declare Minimum,
    constraint_generator => sub {
        my $minimum = shift;
        return sub {
            ! StrictNum->check($_)
                or $_ >= $minimum;
        };
    };

declare ExclusiveMinimum,
    constraint_generator => sub {
        my $minimum = shift;
        return sub { 
            ! StrictNum->check($_)
                or $_ > $minimum;
        }
    };

declare Maximum,
    constraint_generator => sub {
        my $max = shift;
        return sub {
            ! StrictNum->check($_)
                or $_ <= $max;
        };
    };

declare ExclusiveMaximum,
    constraint_generator => sub {
        my $max = shift;
        return sub { 
            ! StrictNum->check($_)
                or $_ < $max;
        }
    };


1;
