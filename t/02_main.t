#!/usr/bin/perl -w

# Primary testing for Object::Destroyer

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use Test::More tests => 17;
use Scalar::Util 'blessed';
use Object::Destroyer;

# Make sure a plain Foo object pair behaves as expected
is( $Foo::destroy_counter, 0, 'DESTROY counter returns expected value' );
my $pair = Foo->new;
isa_ok( $pair, 'Foo' );
isa_ok( $pair->{spouse}, 'Foo' );
isa_ok( $pair->{spouse}->{spouse}, 'Foo' );
is( $pair->hello, 'Hello World!', 'Foo->hello returns as expected' );
is( $pair->hello('Bob'), 'Hello Bob!', 'Foo->hello(args) returns as expected' );
$pair->DESTROY;
is( $Foo::destroy_counter, 2, 'DESTROY counter returns expected value' );

# Make sure that when we use a lexically scoped circular pair, they leak as expected
{ Foo->new }
is( $Foo::destroy_counter, 2, "Circularly dependant object don't automatically DESTROY" );





# Create a Object::Destroyer object with a pair in it
my $temp = Foo->new;
my $Foo = Object::Destroyer->new( $temp );
is( blessed $Foo, 'Object::Destroyer', 'New object is an Object::Destroyer' );
isa_ok( $$Foo, 'Foo' );
is( $Foo->hello, 'Hello World!', 'Normals methods pass through correctly' );
is( $Foo->hello('Sam'), 'Hello Sam!', 'Normals methods with params pass through correctly' );
eval { $temp->foo; }; my $native_error = $@; eval { $Foo->foo; };
$DB::single = $DB::single = 1;
$native_error =~ s/\.(?=\n$)//; # perl adds a trailing fullstop, Carp doesn't.
is( $native_error, $@, 'Errors match on bad method case' );

# Does the ->new method pass through the Wrapper
isa_ok( $Foo->new, 'Foo' );

is( $Foo::destroy_counter, 2, 'DESTROY counter returns as expected' );
undef $Foo;
is( $Foo::destroy_counter, 4, 'DESTROY counter returns as expected' );





# Test a fully implicit create, dropping out of scope, DESTROY cycle
{ Object::Destroyer->new( Foo->new ) }
is( $Foo::destroy_counter, 6, 'Implicit create/exitscope/DESTROY cycle worked' );






#####################################################################
# Test Classes

package Foo;

use vars qw{$destroy_counter};
BEGIN { $destroy_counter = 0 }

sub new {
	my $class = ref $_[0] ? ref shift : shift;

	# Create TWO object, that reference each other in a circular
	# relationship, and return one of them.
	my $first = bless {}, $class;
	my $second = bless { spouse => $first }, $class;
	$first->{spouse} = $second;

	$first;
}

sub hello { shift; @_ ? "Hello $_[0]!" : "Hello World!" }

sub DESTROY { 
	if ( keys %{$_[0]} ) {
		%{$_[0]} = ();
		$destroy_counter++;
	}
}

1;
