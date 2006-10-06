use strict;
use inc::Module::Install;

name           'Object-Destroyer';
all_from       'lib/Object/Destroyer';
requires       'Carp'       => 0;
build_requires 'Test::More' => '0.42';

WriteAll;
