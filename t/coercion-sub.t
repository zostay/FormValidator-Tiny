#!/usr/bin/perl

use Test2::V0;

use FormValidator::Tiny;

validation_spec 'edit' => [
    name => [
        into => sub { "$_$_" },
    ],
];

{
    my ($p, $e) = validate edit => {
        name => 'Foo',
    };

    is $e, undef, 'no errors';
    is $p->{name}, 'FooFoo', 'coercer concatted value to self';
}

done_testing;
