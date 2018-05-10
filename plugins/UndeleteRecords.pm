package Koha::Plugin::UndeleteRecords;
# David Bourgault, 2017 - Inlibro
#
# This plugin allows you to merge multiple reports into one.
#
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
use Modern::Perl;
use strict;
use CGI;
use utf8;
use base qw(Koha::Plugins::Base);
use C4::Auth;
use C4::Context;
use Data::Dumper;

our $VERSION = 0.3;
our $metadata = {
	name            => 'UndeleteRecords',
	author          => 'David Bourgault',
	description     => 'Undelete records',
	date_authored   => '2017-11-15',
	date_updated    => '2018-05-10',
	minimum_version => '16.05',
	maximum_version => undef,
	version         => $VERSION,
};

our $dbh = C4::Context->dbh();

sub new {
	my ( $class, $args ) = @_;
	## We need to add our metadata here so our base class can access it
	$args->{metadata} = $metadata;
	$args->{metadata}->{class} = $class;
	## Here, we call the 'new' method for our base class
	## This runs some additional magic and checking
	## and returns our actual $self
	my $self = $class->SUPER::new($args);

	return $self;
}

sub tool {
    my ( $self, $args ) = @_;
	my $cgi = $self->{cgi};

	if ( $cgi->param('action') eq 'calculate') {
		$self->calculate(
			$cgi->param('target'),
            $cgi->param('FromDate'),
            $cgi->param('ToDate'),
            $cgi->param('test[]')
        );
	}
	elsif ( $cgi->param('action') eq 'merge' and $cgi->param('confirm') eq 'confirm' ) {
		$self->fusion(
			$cgi->param('target'),
            $cgi->param('selected_itemnumbers[]'),
		);
	}
	else {
		$self->home();
	}
}

sub tmpl {
	my $self = shift;
	my $cgi = $self->{cgi};
	my $preferedLanguage = $cgi->cookie('KohaOpacLanguage');

	# Get language-appropriate template, default on english
	my $template = undef;
	eval {$template = $self->get_template( { file => "home_" . $preferedLanguage . ".tt" } )};
	if( !$template ){
		$preferedLanguage = substr $preferedLanguage, 0, 2;
		eval {$template = $self->get_template( { file => "home_$preferedLanguage.tt" } )};
	}
	$template = $self->get_template( { file => 'home.tt' } ) unless $template;

	return $template
}

sub home {
	my $self = shift;
	my $cgi = $self->{cgi};
	my $template = $self->tmpl;
	print $cgi->header(-type => 'text/html',-charset => 'utf-8');
	print $template->output();
}

sub calculate {
	my $self = shift;
	my $target = shift;
    my $FromDate = shift;
    my $ToDate = shift;
	my $cgi = $self->{cgi};
	my $template = $self->tmpl;
    my $all_deleted_sql = "SELECT deleteditems.itemnumber, deleteditems.barcode, COALESCE(deletedbiblio.title,biblio.title),
            COALESCE(deletedbiblio.author, biblio.author), COALESCE(deletedbiblioitems.isbn, biblioitems.isbn), 
            deleteditems.biblionumber, deleteditems.timestamp, IF(deleteditems.barcode 
            IN (
                SELECT items.barcode 
                FROM items
                ), '*', '') 
        FROM deleteditems
        LEFT JOIN deletedbiblioitems ON deleteditems.biblionumber = deletedbiblioitems.biblionumber 
        LEFT JOIN deletedbiblio ON deleteditems.biblionumber = deletedbiblio.biblionumber
        LEFT JOIN biblio ON deleteditems.biblionumber = biblio.biblionumber
        LEFT JOIN biblioitems ON deleteditems.biblionumber = biblioitems.biblionumber
        WHERE deleteditems.timestamp >= '$FromDate' 
            AND deleteditems.timestamp <= IF('$ToDate' LIKE '' AND '$FromDate' NOT LIKE '', NOW(), '$ToDate');";
    my $sth = $dbh->prepare($all_deleted_sql);
    $sth->execute();
    my @all_itemnumber = ( );
    my @all_barcode = ( );
    my @all_title = ( );
    my @all_author = ( );
    my @all_isbn = ( );
    my @all_biblio = ( );
    my @all_timestamp = ( );
    my @all_issimilarbarcode = ( );
    while(my @row = $sth->fetchrow_array()){
        push(@all_itemnumber, $row[0]);
        push(@all_barcode, $row[1]);
        push(@all_title, $row[2]);
        push(@all_author, $row[3]);
        push(@all_isbn, $row[4]);
        push(@all_biblio, $row[5]);
        push(@all_timestamp, $row[6]);
        push(@all_issimilarbarcode, $row[7]);
    }

    $template->param(
		target => $target,
        all_itemnumbers => \@all_itemnumber,
        all_barcodes => \@all_barcode,
        all_titles => \@all_title,
        all_authors => \@all_author,
        all_isbn => \@all_isbn,
        all_biblionumbers => \@all_biblio,
        all_timestamps => \@all_timestamp,
        all_issimilarbarcode => \@all_issimilarbarcode,
        from_date => $FromDate,
        to_date => $ToDate
    );

	print $cgi->header(-type => 'text/html',-charset => 'utf-8');
	print $template->output();
    my $numberitems = scalar @all_itemnumber;

    return $numberitems;
}

sub fusion {
	my $self = shift;
	my $target = shift;
    my @selected_itemnumbers = @_ or undef;
	my $cgi = $self->{cgi};
	my $template = $self->tmpl;
    my $itemnumbers_sql = join ',', @selected_itemnumbers;

    #INSERT
    $dbh->do("INSERT INTO biblio(biblionumber, frameworkcode, author, title, unititle, notes, serial, 
            seriestitle, copyrightdate, timestamp, datecreated, abstract)
        SELECT biblionumber, frameworkcode, author, title, unititle, notes, serial, seriestitle, 
            copyrightdate, timestamp, datecreated, abstract
        FROM deletedbiblio
        WHERE deletedbiblio.biblionumber IN (SELECT biblionumber FROM deleteditems 
        WHERE itemnumber IN ($itemnumbers_sql))
            AND deletedbiblio.biblionumber
                NOT IN (
                        SELECT biblionumber
                        FROM biblio)
    ;");
     
    $dbh->do("INSERT INTO biblioitems(biblioitemnumber, biblionumber, volume, number, itemtype, isbn, issn, ean,
            publicationyear, publishercode, volumedate, volumedesc, collectiontitle, collectionissn,
            collectionvolume, editionstatement, editionresponsibility, timestamp, illus, pages, notes, size,
            place, lccn, url, cn_source, cn_class, cn_item, cn_suffix, cn_sort, agerestriction, totalissues) 
        SELECT biblioitemnumber, biblionumber, volume, number, itemtype, isbn, issn, ean, publicationyear,
            publishercode, volumedate, volumedesc, 
            collectiontitle, collectionissn, collectionvolume, editionstatement, editionresponsibility, timestamp,
            illus, pages, notes, size, place, lccn, url, cn_source, cn_class, cn_item, cn_suffix, cn_sort,
            agerestriction, totalissues 
        FROM deletedbiblioitems 
        WHERE deletedbiblioitems.biblionumber
            IN (
                SELECT biblionumber 
                FROM deleteditems 
                WHERE itemnumber IN ($itemnumbers_sql)
                ) 
            AND deletedbiblioitems.biblionumber
            NOT IN (
                    SELECT biblionumber 
                    FROM biblioitems
                    )
    ;");
    
    $dbh->do("INSERT INTO biblio_metadata(id, biblionumber, format, marcflavour, metadata, timestamp) 
        SELECT id, biblionumber, format, marcflavour, metadata, timestamp 
        FROM deletedbiblio_metadata 
        WHERE deletedbiblio_metadata.biblionumber
            IN (
                SELECT biblionumber 
                FROM deleteditems 
                WHERE itemnumber IN ($itemnumbers_sql)
                ) 
            AND deletedbiblio_metadata.biblionumber
            NOT IN (
                    SELECT biblionumber 
                    FROM biblio_metadata
                    )
    ;");
    
    $dbh->do("INSERT INTO items(itemnumber, biblionumber, biblioitemnumber, barcode, dateaccessioned,
            booksellerid, homebranch, price, replacementprice,replacementpricedate, datelastborrowed,
            datelastseen, stack, notforloan, damaged, damaged_on, itemlost, itemlost_on, withdrawn, withdrawn_on,
            itemcallnumber, coded_location_qualifier, issues, renewals, reserves, restricted, itemnotes,
            itemnotes_nonpublic, holdingbranch, paidfor, timestamp, location, permanent_location, onloan,
            cn_source, cn_sort, ccode, materials, uri, itype, more_subfields_xml, enumchron, copynumber,
            stocknumber, new_status) 
        SELECT itemnumber, biblionumber, biblioitemnumber, IF(barcode 
            IN (
                SELECT barcode 
                FROM items
                ),
            CONCAT(barcode, '_1'), barcode), dateaccessioned, booksellerid, homebranch, price, replacementprice,
            replacementpricedate, datelastborrowed, datelastseen, stack, notforloan, damaged, damaged_on,
            itemlost, itemlost_on, withdrawn, withdrawn_on, itemcallnumber, coded_location_qualifier, issues,
            renewals, reserves, restricted, itemnotes, itemnotes_nonpublic, holdingbranch, paidfor, timestamp,
            location, permanent_location, onloan, cn_source, cn_sort, ccode, materials, uri, itype,
            more_subfields_xml, enumchron, copynumber, stocknumber, new_status 
        FROM deleteditems 
        WHERE deleteditems.itemnumber IN ($itemnumbers_sql)
    ;");
 
    #DELETE
    $dbh->do("DELETE FROM deleteditems 
        WHERE deleteditems.itemnumber IN ($itemnumbers_sql)
    ;");

    $dbh->do("DELETE FROM deletedbiblioitems 
        WHERE deletedbiblioitems.biblionumber
            IN (
                SELECT biblionumber 
                FROM items 
                WHERE itemnumber IN ($itemnumbers_sql)) 
                    AND deletedbiblioitems.biblionumber 
                    IN (
                        SELECT biblionumber 
                        FROM biblioitems
                        )
    ;");

    $dbh->do("DELETE FROM deletedbiblio_metadata 
        WHERE deletedbiblio_metadata.biblionumber
            IN (
                SELECT biblionumber 
                FROM items 
                WHERE itemnumber IN ($itemnumbers_sql)) 
                    AND deletedbiblio_metadata.biblionumber 
                    IN (
                        SELECT biblionumber 
                        FROM biblio_metadata
                        )
    ;");

    $dbh->do("DELETE FROM deletedbiblio 
        WHERE deletedbiblio.biblionumber
            IN (
                SELECT biblionumber 
                FROM items 
                WHERE itemnumber IN ($itemnumbers_sql)) 
                    AND deletedbiblio.biblionumber 
                    IN (
                        SELECT biblionumber 
                        FROM biblio
                        )
    ;");

	print $cgi->header(-type => 'text/html',-charset => 'utf-8');
	print $template->output();
}

1;
