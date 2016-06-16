# Copyright 2015 Solutions inLibro

use Modern::Perl;
package Koha::Plugin::Rapport::Acquisitions;
## Required for all plugins
use FindBin;
use lib $FindBin::Bin;
use Tools;

sub aqcElimination{
    my $refYear = shift;

    my $dbh = C4::Context->dbh;
    my $query = "SELECT count(*) FROM  deleteditems WHERE YEAR(timestamp) = ?";
    my $sth = $dbh->prepare($query);
    $sth->execute($refYear);
    my $count = $sth->fetchrow;

    return ($count);
}

sub aqcDocumentAcquired{
    my $record = shift;
    my $Biblionumber = shift;
    my $refYear = shift;
    my $params = shift;
    my %docAcquired = %$params;

    my $biblio =  C4::Biblio::GetBiblio($Biblionumber);
    my $bibDateCreated = $biblio->{datecreated};

    if ($bibDateCreated && length($bibDateCreated) > 4){
        my $bibCreateYear = substr($bibDateCreated,0,4);
        if ($bibCreateYear eq $refYear){
            my $field040 = $record->field('040');
            if ($field040){
                my $field040a = $field040->subfield("a");
                if ($field040a){
                    my $orgCode = C4::Context->preference('MARCOrgCode');
                    if ($orgCode eq $field040a){
                        $docAcquired{numTitleOriginal}++;
                    } else {
                        $docAcquired{numTitleDerivation}++;
                    }
                }
            }
        }
    }
    return \%docAcquired;
}

sub acqPrintedBook{
    my $record = shift;
    my $Biblionumber = shift;
    my $refYear = shift;
    my $params = shift;
    my %printedBook = %$params;

    if (Koha::Plugin::Rapport::Tools::isPrintedBook($record)){

        my $numItemsOutAcq = Koha::Plugin::Rapport::Tools::getNumItemsFromReferenceYearAndBiblionumber($Biblionumber, $refYear);
        $printedBook{numUnitOutAcq} += $numItemsOutAcq;

        my $numItemsAcq = Koha::Plugin::Rapport::Tools::getNumOrdersFromReferenceYearAndBiblionumber($Biblionumber, $refYear);
        $printedBook{numUnitAcq} += $numItemsAcq;

        if( Koha::Plugin::Rapport::Tools::isQuc($record) ) {
            $printedBook{numProdQucOutAcq} += $numItemsOutAcq;
            $printedBook{numProdQucAcq} += $numItemsAcq;
        }
    }
    return \%printedBook
}

sub acqPrintedSerial{
    my $record = shift;
    my $Biblionumber = shift;
    my $refYear = shift;
    my $params = shift;
    my %printedSerial = %$params;

    if (Koha::Plugin::Rapport::Tools::isPrintedSerial($record)){
        $printedSerial{numTitle}++;
        my $numSubscription = Koha::Plugin::Rapport::Tools::getNumSubscriptionFromReferenceYearAndBiblionumber($Biblionumber, $refYear);
        $printedSerial{numUnit} += $numSubscription;
        if ( Koha::Plugin::Rapport::Tools::isQuc($record) ) {
            $printedSerial{numPubQuc} += $numSubscription;
        }
    }
    return \%printedSerial;
}

sub acqElecBook{
    my $record = shift;
    my $Biblionumber = shift;
    my $refYear = shift;
    my $params = shift;

    my %elecBook = %$params;

    if (Koha::Plugin::Rapport::Tools::isElecBook($record)){
        $elecBook{numTitle}++;
        my $numItems = Koha::Plugin::Rapport::Tools::getNumItemsFromReferenceYearAndBiblionumber($Biblionumber, $refYear);
        $elecBook{numItem} += $numItems;

        my $numItemsAcq = Koha::Plugin::Rapport::Tools::getNumOrdersFromReferenceYearAndBiblionumber($Biblionumber, $refYear);
        $elecBook{numItemAcq} += $numItemsAcq;

        #extract the number of publication units in quebec
        if (Koha::Plugin::Rapport::Tools::isQuc($record)) {
            $elecBook{numTitleQuc}++;
            $elecBook{numItemQuc} += $numItems;
            $elecBook{numItemAcqQuc} += $numItemsAcq;
        }
    }
    return \%elecBook
}
sub acqElecOther {
    my $record = shift;
    my $Biblionumber = shift;
    my $refYear = shift;
    my $params = shift;

    my %elecOther = %$params;

    if (Koha::Plugin::Rapport::Tools::isElecOther($record)){
        $elecOther{numTitle}++;
        my $numItems = Koha::Plugin::Rapport::Tools::getNumItemsFromReferenceYearAndBiblionumber($Biblionumber, $refYear);
        $elecOther{numItem} += $numItems;

        my $numItemsAcq = Koha::Plugin::Rapport::Tools::getNumOrdersFromReferenceYearAndBiblionumber($Biblionumber, $refYear);
        $elecOther{numItemAcq} += $numItemsAcq;
        #extract the number of publication units in quebec
        if (Koha::Plugin::Rapport::Tools::isQuc($record)) {
            $elecOther{numTitleQuc}++;
            $elecOther{numItemQuc} += $numItems;
            $elecOther{numItemAcqQuc} += $numItemsAcq;
        }
    }
    return \%elecOther
}
sub acqElecSerial{
    my $record = shift;
    my $Biblionumber = shift;
    my $refYear = shift;
    my $params = shift;

    my %elecSerial = %$params;

    if( Koha::Plugin::Rapport::Tools::isElecSerial($record) ){;
        my $numSubscription = Koha::Plugin::Rapport::Tools::getNumSubscriptionFromReferenceYearAndBiblionumber($Biblionumber, $refYear);
        $elecSerial{numTitle}++;
        $elecSerial{numUnit} += $numSubscription;
        if ( Koha::Plugin::Rapport::Tools::isQuc($record) ) {
            $elecSerial{numTitleQuc}++;
            $elecSerial{numUnitQuc} += $numSubscription;
        }
    }
    return \%elecSerial;
}



sub acqAudioVisual {
    my $record = shift;
    my $Biblionumber = shift;
    my $refYear = shift;
    my $params = shift;
    my %audioVisual = %$params;

    if (Koha::Plugin::Rapport::Tools::isAudioVisual($record)){
        my $numItemsOutAcq = Koha::Plugin::Rapport::Tools::getNumItemsFromReferenceYearAndBiblionumber($Biblionumber, $refYear);
        $audioVisual{numUnitOutAcq} += $numItemsOutAcq;

        my $numItemsAcq = Koha::Plugin::Rapport::Tools::getNumOrdersFromReferenceYearAndBiblionumber($Biblionumber, $refYear);
        $audioVisual{numUnitAcq} += $numItemsAcq;

    }
    return \%audioVisual;
}
#FIXME the result may be incorrect
sub acqOthers{
    my ($statistiques, $totItems, $totItemsQuebec) = @_;
    my %otherDocument = ();
    my $numUnit = 0;
    my $numProdQuc = 0;
    while ( my ($keyTmp, $hash) = each($statistiques) ) {
        if( $keyTmp =~ "acq" ){
            while ( my ($key, $value) = each($hash) ) {
                if ($key =~ /Unit|Item/){
                    $numUnit+=$value;
                }
                if (index($key, "Quc") != -1){
                    $numProdQuc+=$value;
                }
            }
        }
    }

    $otherDocument{numUnit} = $totItems - $numUnit;
    $otherDocument{numProdQuc} = $totItemsQuebec - $numProdQuc;

    return \%otherDocument;
}

1;
