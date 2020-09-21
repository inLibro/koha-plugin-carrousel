#!/usr/bin/perl

use Modern::Perl;

use Koha::Plugin::Carrousel;
use Koha::Virtualshelves;

my $p = Koha::Plugin::Carrousel->new( { enable_plugins => 1 } );

@Koha::Plugin::Carrousel::shelves =
  Koha::Virtualshelves->search( undef, { order_by => { -asc => 'shelfname' } } );
$p->orderShelves();
$p->generateCarrousels();
