use strict;
use inc::Module::Install;

name            'Object-Destroyer';
all_from        'lib/Object/Destroyer.pm';
requires        'Carp'          => 0; 
test_requires  'Test::More'    => '0.42';

WriteAll();

