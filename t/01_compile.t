#!/usr/bin/perl -w

# Load testing for Object::Destroyer

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use Test::More tests => 3;

ok( $] >= 5.005, "Your perl is new enough" );
use_ok('Object::Destroyer');
use_ok('Object::Destroyer', 1.99);

exit(0);
