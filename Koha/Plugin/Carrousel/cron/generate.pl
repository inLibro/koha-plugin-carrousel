#!/usr/bin/perl

use Modern::Perl;
use Koha::Plugin::Carrousel;

my $p = Koha::Plugin::Carrousel->new( { enable_plugins => 1 } );
$p->generateCarrousels();