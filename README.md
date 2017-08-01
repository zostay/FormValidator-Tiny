[![Build Status](https://travis-ci.org/zostay/FormValidator-Tiny.svg?branch=master)](https://travis-ci.org/zostay/FormValidator-Tiny)
[![Coverage Status](https://coveralls.io/repos/zostay/FormValidator-Tiny/badge.svg?branch=master)](https://coveralls.io/r/zostay/FormValidator-Tiny?branch=master)
[![GitHub issues](https://img.shields.io/github/issues/zostay/FormValidator-Tiny.svg)](https://github.com/zostay/FormValidator-Tiny/issues)
[![Kwalitee status](http://cpants.cpanauthors.org/dist/FormValidator-Tiny.png)](http://cpants.charsbar.org/dist/overview/FormValidator-Tiny)

# NAME

FormValidator::Tiny - A tiny form validator

# VERSION

version 0.001

# SYNOPSIS

    use FormValidator::Tiny qw( :validation :predicates :filtesr );
    use Email::Valid;   # <-- for demonstration, not required
    use Email::Address; # <-- for demonstration, not required
    use Types::Standard qw( Int ); # <-- for demonstration, not required

    validation_spec edit_user => [
        login_name => [
            required => 1,
            must     => limit_character_set('_', 'a-z', 'A-Z', '0-9'),
            must     => length_in_range(5, 16),
        ],
        name => [
            required => 1,
            must     => length_in_range(1, 100),
        ],
        age => [
            optional => 1,
            into     => '+',
            must     => Int,
            must     => number_in_range(13, '*'),
        ],
        password => [
            required => 1,
            must     => length_in_range(8, 72),
        ],
        confirm_password => [
            required => 1,
            must     => equal_to('password'),
        ],
        email => [
            required => 1,
            must     => length_in_range(5, 250),
            must     => sub { (
                            !!Email::Valid->address($_),
                            "That is not a well-formed email address."
                        ) },
            into     => 'Email::Address',
        ],
        groups => [
            optional  => 1,
            into      => split_by(' '),
            into      => '[]',
            each_must => length_in_range(3, 20),
            each_must => limit_character_set(
                             ['_', 'a-z', 'A-Z'],
                             ['_', '-', 'a-z', 'A-Z', '0-9'],
                         ),
        ],
        tags   => [
            optional   => 1,
            into       => split_by(/\s*,\s*/),
            each_into  => split_by(/\s\*:\s*/, 2),
            into       => '{}',
            key_must   => length_in_range(3, 20),
            key_must   => qr/^(?:[A-Z][a-z0-9]*)(?:-[A-Z][a-z0-9]*)*)$/,
            with_error => 'Tags keys must be of a form like "Favorite" or "Welcome-Message".',
            value_must => length_in_range(1, 500),
            value_must => limit_character_set('_', '-', 'a-z', 'A-Z', '0-9'),
        ],
    ];

    # Somehow your web framework gets you a set of form parameters submitted by
    # POST or whatever. GO!
    my $params = web_framework_params_method();
    my ($parsed_params, $errors) = validate edit_user => $params;

    # You probably want better error handling
    if ($errors) {
        for my $field (keys %$errors) {
            print "Error in $field: $_\n" for @{ $errors->{$field} };
        }
    }

    # Form fields are valid, take action!
    else {
        do_the_thing(%$parased_params);
    }

# DESCRIPTION

There are lots for form validators, but this one aims to be the one that just
one thing and does it well without involving anything else if it can. If you
just need a small form validator without installing all of CPAN, this will do
that. If you want to install all of CPAN and use a readable form validation spec
syntax, I hope this will do that too.

This module requires Perl 5.18 or better as of this writing.

# EXPORTED FUNCTIONS

## validation\_spec

    validation_spec $spec_name => \@spec;

This defines a validation specification. It associates a specification named
`$spec_name` with the current package. Any use of `validate` within the
current package will use specifications named within the current package. The
following example would work fine as the "edit" spec defined in each controller
is in their respective package namespaces.

    package MyApp::Controller::User;
    validation_spec edit => [ ... ];
    sub process_edits {
        my ($self, $c) = @_;
        my ($p, $e) = validate edit => $c->req->body_parameters;
        ...
    }

    package MyApp::Controller::Page;
    validation_spec edit => [ ... ];
    sub process_edits {
        my ($self, $c) = @_;
        my ($p, $e) = validate edit => $c->req->body_parameters;
        ...
    }

If you want to define them into a different package, name the package as part of
the spec. Similarly, you can validate using a spec defined in a different
package by naming the package when calling ["validate"](#validate):

    package MyApp::Forms;
    validation_spec MyApp::Controller::User::edit => [ ... ];

    package MyApp::Controller::User;
    sub process_groups {
        my ($self, $c) = @_;
        my ($p, $e) = validate MyApp::Controller::UserGroup::edit => $c->req->body_parameters;
        ...
    }

You can also define your validation specification as lexical variables instead:

    my $spec = validation_spec [ ... ];
    my ($p, $e) = validate $spec, $c->req->body_parameters;

For information about how to craft a spec, see the ["VALIDATION SPECIFICATIONS"](#validation-specifications)
section.

## validate

    my ($params, $errors) = validate $spec, $input_parameters;

Compares the given parameters agains the named spec. The `$input_parameters`
may be provided as either a hash or an array of alternating key-value pairs. All
keys and values must be provided as strings.

The method returns two values. The first, `$params`, is the parameters as far
as they have been validated so far. The second, `$errors` is the errors that
have been detected.

The `$params` will be provided as a hash. The keys of this hash will match the
keys given in the spec. Some keys may be missing if the provided
`$input_parameters` did not contain values or those values are invalid.

If there are no errors, the `$errors` value will be set to `undef`. With
errors, this will be hash of arrays. The keys of the hash will also match the
keys in the spec. Only fields with a validation error will be set. Each value
is an array of strings, with each string being an error message describing a
validation failure.

## limit\_character\_set

    must => limit_character_set(@sets)
    must => limit_character_set(\@fc_sets, \@rc_sets);

This returns a subroutine that limits the allowed characters for an input. In
the first form, the character set limits are applied to all characters in the
value. In the second, the first array limits the characters permitted for the
first character and the second limits the characters permitted for the rest.

Character sets may be provided as single letters (e.g., "\_"), as named unicode
character properties wrapped in square brackets (e.g., "\[Uppercase\_Letter\]"), or
as ranges connected by a hyphen (e.g., "a-z").

## length\_in\_range

    must => length_in_range('*', 10)
    must => length_in_range(10, '*')
    must => length_in_range(10, 100)

This returns a subroutine for use with `must` declarations that asserts the
minimum and maximum string character length permitted for a value. Use an
asterisk to define no limit.

## equal\_to

    must => equal_to('field')

This returns a subroutine for use with `must` declarations that asserts that
the value must be exactly equal to another field in the input.

## number\_in\_range

    must => number_in_range('*', 100)
    must => number_in_range(100, '*')
    must => number_in_range(100, 500)
    must => number_in_range(exclusive => 100, exclusive => 500)

Returns a predicate for must that requires the integer to be within the given range. The endpoints are inclusive by default. You can add the word "exclusive" before a value to make the comparison exclusive instead. Using a '\*' indicates no limit at that end of the range.

## split\_by

    into => split_by(' ')
    into => split_by(qr/,\s*/)
    into => split_by(' ', 2)
    into => split_by(qr/,\s*/, 10)

Returns an into filter that splits the string into an array. The arguments are
similar to those accepted by Perl's built-in `split`.

## trim

    into => trim
    into => trim('left')
    into => trim('right')

Returns an into filter that trims whitespace from the input value. You can
provide an argument to trim only the left whitespace or the right whitespace.

# VALIDATION SPECIFICATIONS

The validation specification is an array reference. Each key names a field to
validate. The value is an array of processing declarations. Each processing
declaration is a key-value pair. The inputs will be processed in the order they
appear in the spec. The key names the type of processing. The value describes
arguments for the processing. The processing declarations will each be executed
in the order they appear. The same processor may be applied multiple times.

## Input Declarations

Input declarations modify the initial value and must be given at the very top of
the list of declarations for a field before all others.

### from

    from => 'input_parameter_name'

Without this declaration, the validator pulls input from the parameter with the
same name as the key named in the validation spec. This input declaration
changes the key used for input.

### as

    multiple => 1

The multiple input declaration tells the validator weather to interpret the
input parameter as a multiple input or not. Without this declaration or with it
set to 0, the validator will interpret multiple inputs as a single value,
ignoring all but the last. With this declaration, it treat the input as multiple
items, even if there are 0 or 1.

### trim

    trim => 0

The default behavior of ["validate"](#validate) is to trim whitespace from the beginning
and end of a value before processing. You can use the `trim` declaration to
disable that.

## Filtering Declarations

Filtering declarations inserted into the validation spec will replace the input
value with the newly filtered value at the point at which the declaration is
encountered.

### into

    into => '+'
    into => '?'
    into => '?+'
    into => '?perl'
    into => '?yes!no',
    into => '[]'
    into => '{}'
    into => 'Package::Name'
    into => sub { ... }
    into => TypeObject

This is a filter declaration that transforms the input using the named coercion.

- Numeric

    Numeric coercion is performed using the '+' argument. This will convert the
    value using Perl's built-in string-to-number conversion.

- Boolean

    Boolean coercion is performed using the '?' argument. This will convert the
    value to boolean. It does not use Perl's normal mechanism, though. Instead, it
    converts the string to boolean based on string length alone. If the string is
    empty, it is false. If it is not empty it is true.

- Boolean by Numeric

    Boolean by Numeric coercion is performed using the '?+' argument. This will
    first convert the string input to a number and then the number will be collapsed
    to a boolean value such that 0 is false and any other value is true.

- Boolean via Perl

    Boolean via Perl coercion is performed using the '?perl' argument. This will
    convert to boolean using Perl's usual boolean logic.

- Boolean via Enumeration

    Boolean via Enumeration coercion is performed using an argument that starts with
    a question mark, '?', and contains an exclamation mark, '!'. The value between
    the question mark and exclamation mark is the value that must be provided for a
    true value. The value provided between the exclamation mark and the end of
    string is the false value. Anything else will be treated as invalid and cause a
    validation error.

- Array

    Using a value of '\[\]' will make sure the value is treated as an array. This is a
    noop if the ["multiple"](#multiple) declaration is set or if a ["filter"](#filter) returns an array.
    If the value is still a single, though, this will make sure the input value is
    placed inside an array references. This will also turn a hash value into an array.

- Hash

    Setting the declaration to '{}" will coerce the value to a hash. The even indexed
    values in the array will become keys and the odd indexed values in the array
    will become their respective values. If the value is not an array, it will turn
    a single value into a key/value pair with the key and the pair both being equal
    to the original value.

- Package

    A package coercion happens when the string given is a package name. This assumes
    that passing the input value to the `new` constructor of the named package will
    do the right thing. If you need anything more complicated than that, you should
    use a subroutine coercion.

- Subroutine

    A subroutine coercion converts the value using the given subroutine. The current
    input value is passed as the single argument to the coercion (and also set as
    the localized copy of `$_`). The return value of the subroutine becomes the new
    input value.

- Type::Tiny Coercion

    If an object is passed that provides a `coerce` method. That method will be
    called on the current input value and the result will be used as the new input
    value.

### each\_into

    each_into => '+'
    each_into => '?'
    each_into => '?+'
    each_into => '?perl'
    each_into => '?yes!no',
    each_into => '[]'
    each_into => '{}'
    each_into => 'Package::Name'
    each_into => sub { ... }
    each_into => TypeObject

Performs the same coercion as ["into"](#into), but also works with arrays and hashes.
It will apply the filter to a single value or to all elements of an array or to
all keys and values of a hash.

### key\_into

    key_into => '+'
    key_into => '?'
    key_into => '?+'
    key_into => '?perl'
    key_into => '?yes!no',
    key_into => '[]'
    key_into => '{}'
    key_into => 'Package::Name'
    key_into => sub { ... }
    key_into => TypeObject

Performs the same coercion as ["into"](#into), but also works with arrays and hashes.
It will apply the filter to a single value or to all even index elements of an
array or to all keys of a hash.

### value\_into

    value_into => '+'
    value_into => '?'
    value_into => '?+'
    value_into => '?perl'
    value_into => '?yes!no',
    value_into => '[]'
    value_into => '{}'
    value_into => 'Package::Name'
    value_into => sub { ... }
    value_into => TypeObject

Performs the same coercion as ["into"](#into), but also works with arrays and hashes.
It will apply the filter to a single value or to all odd index elements of an
array or to all values of a hash.

## Validation Declarations

### required

    required => 1

This is a validation rule that marks the parameter as required. Any setting of
the value will pass this validation. Setting the value to 0 will disable the
requirement.

### optional

    optional => 1

This is the opposite of ["required"](#required). Setting the value to 1 means no check, but
to 0 is the same as `required` being set to 1.

### must

    must => qr/.../
    must => sub { ... }
    must => TypeObject

This declaration states that the input given must match the described predicate.
The module supports three kinds of predicates:

- Regular Expression

    This will match the given regular expression against the input. It is
    recommended that the regular expression start with "^" or "\\A" and end with "$"
    or "\\z" to force a total string match.

    The error message for these validates is not very good, so you probably want to
    combine use of this kind of predicate with a following ["with\_error"](#with_error)
    declaration.

- Subroutine

    The subroutine will be passed a two values. The first is the input to test
    (which will also be set in the localalized copy of `$_`). This second value
    passed is rest of the input as processing currently stands. The output may come
    as a single or two values. The first value returned is always a boolean
    indicating whether the validation has passed. The second value is the error
    message to use.  If only a single value is returned, you may still set the error
    message with a following ["with\_error"](#with_error) declaration.

    Without a `with_error` declaration or a second value, the error message will
    not be very helpful.

- Type::Tiny Object

    The third option is to use a [Type::Tiny](https://metacpan.org/pod/Type::Tiny)-style type object. The ["validate"](#validate)
    routine merely checks to see if it is an object that provides a `check` method
    or a `validate` method. If it provides a `check` method, that method will be
    called and the boolean value returned will be treated as the success or failure
    to validate. In this case, the error message will be pulled from a call to
    `get_message`, if such a method is provided. In the `validate` case, it will
    be called and a true value will be treated as the error message and a false
    value as validation success.

    It is my experience that the error messages provided by [Type::Tiny](https://metacpan.org/pod/Type::Tiny) and
    similar type systems are not friendly for use with end-uers. As such, it is
    recommended that you provide a nicer error message with a following
    ["with\_error"](#with_error) declaration.

### each\_must

    each_must => qr/.../
    each_must => sub { ... }
    each_must => TypeObject

This declaration establishes validation rules just like ["must"](#must), but applies
the test to every value. If the input is an array, that will apply to every
value. If the input is a hash, it will apply to every key and every value of the
hash. If it is a single scalar, it will apply to that single value.

### key\_must

    key_must => qr/.../
    key_must => sub { ... }
    key_must => TypeObject

This is very similar to `each_must`, but only applies to keys. It will apply to
a single value, or to the even index values of an array, or to the keys of a
hash.

### value\_must

    value_must => qr/.../
    value_must => sub { ... }
    value_must => TypeObject

This is very similar to `each_must` and complement of `key_must`. It will
apply to a single value, or to the odd index values of an array, or to the
values of a hash.

### with\_error

    with_error => 'Error message.'
    with_error => sub { ... }

This defines the error message to associate with the previous `must`,
`each_must`, `key_must`, `value_must`, `into`, `required`, and `optional`
declaration. This will override any other associated message.

If you would like to provide a different message based on the input, you may
provide a subroutine.

# SPECIAL VARIABLES

The validation specifications are defined in each packages where
["validation\_spec"](#validation_spec) is called. This is done through a package variable named
`%FORM_VALIDATOR_TINY_SPECIFICATION`. If you really need to use that variable
for something else or if defining global package variables offends you, you can
use the return value form of `validation_spec`, which will avoid creating this
variable.

If you stick to the regular interface, however, this variable will be
established the first time `validation_spec` is called. The spec names are the
keys and the values have no documented definition. If you want to see what they
are, you must the read the code, but there's no guarantee that the internal
representation of this variable will stay the same in future releases.

# AUTHOR

Andrew Sterling Hanenkamp <hanenkamp@cpan.org>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2017 by Qubling Software LLC.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
