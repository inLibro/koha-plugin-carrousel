# Copyright 2015 Solutions inLibro

use Modern::Perl;
package Koha::Plugin::Rapport::Use;
## Required for all plugins
use FindBin;
use lib $FindBin::Bin;
use Tools;

sub useNumLoanUnit{
    my $record = shift;
    my $Biblionumber = shift;
    my $refYear = shift;
    my $params = shift;
    my %useNumLoanUnit = %$params;
    my $numUnit = 0;
    my @arrType = ();

    if (Koha::Plugin::Rapport::Tools::isPrintedBook($record)){
        @arrType = qw(A S P);
        $useNumLoanUnit{numUnitPrintedBookAdult} += Koha::Plugin::Rapport::Tools::getNumIssuesFromReferenceYearAndCategoryTypeAndBiblionumber($Biblionumber, $refYear, \@arrType);
        @arrType = qw(C);
        $useNumLoanUnit{numUnitPrintedBookChild} += Koha::Plugin::Rapport::Tools::getNumIssuesFromReferenceYearAndCategoryTypeAndBiblionumber($Biblionumber, $refYear, \@arrType);
    } elsif (Koha::Plugin::Rapport::Tools::isPrintedSerial($record)){
        @arrType = qw(A S P);
        $useNumLoanUnit{numUnitPrintedSerialAdult} += Koha::Plugin::Rapport::Tools::getNumIssuesFromReferenceYearAndCategoryTypeAndBiblionumber($Biblionumber, $refYear, \@arrType);
        @arrType = qw(C);
        $useNumLoanUnit{numUnitPrintedSerialChild} += Koha::Plugin::Rapport::Tools::getNumIssuesFromReferenceYearAndCategoryTypeAndBiblionumber($Biblionumber, $refYear, \@arrType);
    } elsif (Koha::Plugin::Rapport::Tools::isAudioVisual($record)){
        @arrType = qw(A S P);
        $useNumLoanUnit{numUnitAudioVisualAdult} += Koha::Plugin::Rapport::Tools::getNumIssuesFromReferenceYearAndCategoryTypeAndBiblionumber($Biblionumber, $refYear, \@arrType);
        @arrType = qw(C);
        $useNumLoanUnit{numUnitAudioVisualChild} += Koha::Plugin::Rapport::Tools::getNumIssuesFromReferenceYearAndCategoryTypeAndBiblionumber($Biblionumber, $refYear, \@arrType);
    } elsif (Koha::Plugin::Rapport::Tools::isElecBook($record)) {
        @arrType = qw(A S P);
        $useNumLoanUnit{numUnitDigitalDocumentAdult} += Koha::Plugin::Rapport::Tools::getNumIssuesFromReferenceYearAndCategoryTypeAndBiblionumber($Biblionumber, $refYear, \@arrType);
        @arrType = qw(C);
        $useNumLoanUnit{numUnitDigitalDocumentChild} += Koha::Plugin::Rapport::Tools::getNumIssuesFromReferenceYearAndCategoryTypeAndBiblionumber($Biblionumber, $refYear, \@arrType);
    } elsif (Koha::Plugin::Rapport::Tools::isElecOther($record)) {
        @arrType = qw(A S P);
        $useNumLoanUnit{numUnitOtherDigitalDocumentAdult} += Koha::Plugin::Rapport::Tools::getNumIssuesFromReferenceYearAndCategoryTypeAndBiblionumber($Biblionumber, $refYear, \@arrType);
        @arrType = qw(C);
        $useNumLoanUnit{numUnitOtherDigitalDocumentChild} += Koha::Plugin::Rapport::Tools::getNumIssuesFromReferenceYearAndCategoryTypeAndBiblionumber($Biblionumber, $refYear, \@arrType);
    } else {
        @arrType = qw(A S P);
        $useNumLoanUnit{numUnitOtherDocumentAdult} += Koha::Plugin::Rapport::Tools::getNumIssuesFromReferenceYearAndCategoryTypeAndBiblionumber($Biblionumber, $refYear, \@arrType);
        @arrType = qw(C);
        $useNumLoanUnit{numUnitOtherDocumentChild} += Koha::Plugin::Rapport::Tools::getNumIssuesFromReferenceYearAndCategoryTypeAndBiblionumber($Biblionumber, $refYear, \@arrType);
    }
    return \%useNumLoanUnit;
}

sub useNumRegistredUsers{
    my $refYear = shift;
    my %useNumRegistred = ();

    my @arrType = qw(A S P);
    $useNumRegistred{numAdult} = Koha::Plugin::Rapport::Tools::getNumUsersFromReferenceYearAndCategorytype($refYear, \@arrType);
    @arrType = qw(C);
    $useNumRegistred{numChild} = Koha::Plugin::Rapport::Tools::getNumUsersFromReferenceYearAndCategorytype($refYear, \@arrType);
    @arrType = qw(I);
    $useNumRegistred{numInstitution} = Koha::Plugin::Rapport::Tools::getNumUsersFromReferenceYearAndCategorytype($refYear, \@arrType);
    $useNumRegistred{numFemale} = Koha::Plugin::Rapport::Tools::getNumUsersFromReferenceYearAndSex($refYear, "F");
    $useNumRegistred{numMale} = Koha::Plugin::Rapport::Tools::getNumUsersFromReferenceYearAndSex($refYear, "M");
    $useNumRegistred{numActives} = Koha::Plugin::Rapport::Tools::getNumActivesUsersFromReferenceYear($refYear);

    return \%useNumRegistred;
}
sub useNumRenewal {
     my $refYear = shift;
     return Koha::Plugin::Rapport::Tools::getGetRenewalsFromReferenceYear($refYear);
}
1;
