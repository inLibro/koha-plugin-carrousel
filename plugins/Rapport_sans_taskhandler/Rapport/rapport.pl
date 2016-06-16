#!/usr/bin/perl
use Modern::Perl;
use Getopt::Long;
use strict;
use warnings;

#charger les modules qui sont dans la dossier locale
use FindBin;
use lib $FindBin::Bin;

use Time::Piece;
use XML::LibXML;
use XML::LibXSLT;
use XML::Simple;

use Acquisitions;
use C4::Biblio;
use C4::Context;
use C4::Items;
use Funds;
use MARC::Record;
use Tools;
use Use;


my $time = Time::Piece->new();
#Trouver le repertour des plugins pour acceder aux fichiers necessaires pour la generation du rapport.
my $baseDirectory = C4::Context->config('pluginsdir');
our $scriptDirectory = $baseDirectory."/Koha/Plugin/Rapport";

#année de référence
my $refYear = $time->year - 1; #default

GetOptions(
   'year:i' => \$refYear,
);

my $folder = "$scriptDirectory/rapports";

my $outfile = "$folder/rapport_$refYear.xml";

if (not -d $folder){
    `mkdir -p $folder`;
}

$Data::Dumper::Purity = 1;
open FILE, ">$outfile" or die "Can't open '$outfile':$!";
#print FILE Dumper (extractStats());
print FILE (XMLout(extractStats(), NoAttr => 1));
close FILE;

my $xslt = XML::LibXSLT->new();

#xml file
my $source = XML::LibXML->load_xml(location => "$outfile");
#xsl file
my $style_doc = XML::LibXML->load_xml(location=>"$scriptDirectory/rapport.xsl", no_cdata=>1);

my $stylesheet = $xslt->parse_stylesheet($style_doc);
my $results = $stylesheet->transform($source);

$outfile = "$folder/rapport_$refYear.html";

open FILE, ">$outfile" or die "Can't open '$outfile':$!";
#print FILE $stylesheet->output_as_chars($results);
print FILE $stylesheet->output_as_bytes($results);

sub extractStats{
    my %statistiques;
    my $dbh = C4::Context->dbh();

    my $querybiblio = q|
                   SELECT distinct biblionumber
                   FROM biblio LEFT JOIN items USING(biblionumber)
                   WHERE YEAR(biblio.datecreated) <= ?
                   OR YEAR(items.dateaccessioned) <= ?
                 |;
    my $arrBiblio = $dbh->selectcol_arrayref($querybiblio, undef, ($refYear, $refYear));

    my $querydeletedbiblio = q|
                   SELECT distinct biblionumber
                   FROM deletedbiblio LEFT JOIN deleteditems USING(biblionumber)
                   WHERE (YEAR(deletedbiblio.datecreated) <= ?
                   OR YEAR(deleteditems.dateaccessioned) <= ?)
                   AND YEAR(deletedbiblio.timestamp)> ?
                 |;
    my $arrDeletedBiblio = $dbh->selectcol_arrayref($querydeletedbiblio, undef, ($refYear, $refYear, $refYear));


    my $arrBiblionumber = [@$arrBiblio, @$arrDeletedBiblio];

    my $totItems = 0;
    my $totItemsYear = 0;
    my $totItemsQuebec = 0;
    my %fundPrintedBook = ();
    my %fundPrintedSerial = ();
    my %fundAudioVisual = ();
    my %fundElectronicSerial = ();
    my %fundElectronicBook = ();
    my %fundElectronicOther = ();
    my %fundOtherDocument = ();
    my %acqPrintedBook = ();
    my %acqPrintedSerial = ();
    my %acqElectronicBook = ();
    my %acqElectronicSerial = ();
    my %acqElectronicOther = ();
    my %acqAudioVisual = ();
    my %acqDocAcquired = ();
    my %useNumLoanUnit = ();

    Koha::Plugin::Rapport::Tools::initFundHashs(\%fundPrintedBook,\%fundPrintedSerial,\%fundAudioVisual,\%fundElectronicSerial,\%fundElectronicBook,\%fundOtherDocument,\%fundElectronicOther);
    Koha::Plugin::Rapport::Tools::initAcquisitionHashs(\%acqPrintedBook,\%acqPrintedSerial,\%acqAudioVisual,\%acqDocAcquired, \%acqElectronicBook, \%acqElectronicSerial, \%acqElectronicOther);
    Koha::Plugin::Rapport::Tools::initUseHashs(\%useNumLoanUnit);

    foreach my $Biblionumber (@$arrBiblionumber){
        my $record = GetMarcBiblio($Biblionumber);
        my $numItems = Koha::Plugin::Rapport::Tools::getNumItemsUntilReferenceYear($Biblionumber, $refYear);
        my $numItemsYearOnly = Koha::Plugin::Rapport::Tools::getNumItemsFromReferenceYearAndBiblionumber($Biblionumber, $refYear);

        if ($record) {
            #fill printed book statistiques from funds module
            my $returnPrintedBook = Koha::Plugin::Rapport::Funds::fundsPrintedBook($record, $numItems, \%fundPrintedBook);
            %fundPrintedBook = %$returnPrintedBook;

            #fill printed serial statistiques from funds module
            my $returnPrintedSerial = Koha::Plugin::Rapport::Funds::fundsPrintedSerial($record, $numItems, \%fundPrintedSerial);
            %fundPrintedSerial = %$returnPrintedSerial;

            #fill audio visual statistiques from funds module
            my $returnAudioVisual = Koha::Plugin::Rapport::Funds::fundsAudioVisual($record, $numItems, \%fundAudioVisual);
            %fundAudioVisual = %$returnAudioVisual;

            #fill electronic serial statistiques from funds module
            my $returnElecSerial = Koha::Plugin::Rapport::Funds::fundsElecSerial($record, $numItems, \%fundElectronicSerial);
            %fundElectronicSerial = %$returnElecSerial;

            #fill electronic book statistiques from funds module
            my $returnElecBook = Koha::Plugin::Rapport::Funds::fundsElecBook($record, $numItems, \%fundElectronicBook);
            %fundElectronicBook = %$returnElecBook;

            #fill others electronic documents statistiques from funds module
            my $returnElecOther = Koha::Plugin::Rapport::Funds::fundsElecOther($record, $numItems, \%fundElectronicBook);
            %fundElectronicBook = %$returnElecOther;

            #fill documents acquired statistiques from acquisitions module
            my $returnDocAcquired = Koha::Plugin::Rapport::Acquisitions::aqcDocumentAcquired($record, $Biblionumber, $refYear, \%acqDocAcquired);
            %acqDocAcquired = %$returnDocAcquired;

            #fill printed book statistiques from acquisitions module
            my $returnAcqPrintedBook = Koha::Plugin::Rapport::Acquisitions::acqPrintedBook($record, $Biblionumber, $refYear, \%acqPrintedBook);
            %acqPrintedBook = %$returnAcqPrintedBook;

            #fill printed serial statistiques from acquisitions module
            my $returnAcqPrintedSerial = Koha::Plugin::Rapport::Acquisitions::acqPrintedSerial($record, $Biblionumber, $refYear, \%acqPrintedSerial);
            %acqPrintedSerial = %$returnAcqPrintedSerial;

            #fill audio visual statistiques from acquisitions module
            my $returnAcqAudioVisual = Koha::Plugin::Rapport::Acquisitions::acqAudioVisual($record, $Biblionumber, $refYear, \%acqAudioVisual);
            %acqAudioVisual = %$returnAcqAudioVisual;

            #fill electronic serial statistiques from acquisitions module
            my $returnAcqElecSerial = Koha::Plugin::Rapport::Acquisitions::acqElecSerial($record, $Biblionumber, $refYear, \%acqElectronicSerial);
            %acqElectronicSerial = %$returnAcqElecSerial;

            #fill electronic book statistiques from acquisitions module
            my $returnAcqElecBook = Koha::Plugin::Rapport::Acquisitions::acqElecBook($record,  $Biblionumber, $refYear, \%acqElectronicBook);
            %acqElectronicBook = %$returnAcqElecBook;

            #fill electronic book statistiques from acquisitions module
            my $returnAcqElecOther = Koha::Plugin::Rapport::Acquisitions::acqElecOther($record, $Biblionumber, $refYear, \%acqElectronicOther);
            %acqElectronicOther = %$returnAcqElecOther;

            #fill loan statistiques from use module
            my $returnUseNumLoanUnit = Koha::Plugin::Rapport::Use::useNumLoanUnit($record, $Biblionumber, $refYear, \%useNumLoanUnit);
            %useNumLoanUnit = %$returnUseNumLoanUnit;

            #aux subrotine to compute the total of units producted in Quebec
            Koha::Plugin::Rapport::Tools::getNumProdQuc($record, $numItems, \$totItemsQuebec);
        }

        $totItems += $numItems;
        $totItemsYear += $numItemsYearOnly;
    }

    $statistiques{fundPrintedBook} = \%fundPrintedBook;
    $statistiques{fundPrintedSerial} = \%fundPrintedSerial;
    $statistiques{fundAudioVisual} = \%fundAudioVisual;
    $statistiques{fundElectronicSerial} = \%fundElectronicSerial;
    $statistiques{fundElectronicBook} = \%fundElectronicBook;
    $statistiques{fundElectronicOther} = \%fundElectronicOther;
    my $returnOtherDocument = Koha::Plugin::Rapport::Funds::fundsOthers(\%statistiques, $totItems, $totItemsQuebec);
    $statistiques{fundOtherDocument} = \%$returnOtherDocument;

    $statistiques{acqPrintedBook} = \%acqPrintedBook;
    $statistiques{acqPrintedSerial} = \%acqPrintedSerial;
    $statistiques{acqElectronicBook} = \%acqElectronicBook;
    $statistiques{acqElectronicSerial} = \%acqElectronicSerial;
    $statistiques{acqElectronicOther} = \%acqElectronicOther;
    $statistiques{acqAudioVisual} = \%acqAudioVisual;
    my $acqOtherDocument = Koha::Plugin::Rapport::Acquisitions::acqOthers(\%statistiques, $totItemsYear, $totItemsQuebec);
    $statistiques{acqOtherDocument} = $acqOtherDocument;
    $statistiques{acqDocAcquired} = \%acqDocAcquired;
    $statistiques{acqElimination}{numUnit} = Koha::Plugin::Rapport::Acquisitions::aqcElimination($refYear);

    $statistiques{useNumLoanUnit} = \%useNumLoanUnit;
    $statistiques{useNumRegistredUsers} = Koha::Plugin::Rapport::Use::useNumRegistredUsers($refYear);

    $statistiques{useNumRenewal} = Koha::Plugin::Rapport::Use::useNumRenewal($refYear);

    return \%statistiques;
}
