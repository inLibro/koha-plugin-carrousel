# Copyright 2015 Solutions inLibro

use Modern::Perl;
use FindBin;
use lib $FindBin::Bin;
use Dumper;
package Koha::Plugin::Rapport::Tools;

sub initUseHashs{
    my $loanUnit = shift;

    $loanUnit->{numUnitAudioVisualAdult} = 0;
    $loanUnit->{numUnitAudioVisualChild} = 0;
    $loanUnit->{numUnitPrintedBookAdult} = 0;
    $loanUnit->{numUnitPrintedBookChild} = 0;
    $loanUnit->{numUnitPrintedSerialAdult} = 0;
    $loanUnit->{numUnitPrintedSerialChild} = 0;
    $loanUnit->{numUnitOtherDocumentAdult} = 0;
    $loanUnit->{numUnitOtherDocumentChild} = 0;
    $loanUnit->{numUnitDigitalDocumentAdult} = 0;
    $loanUnit->{numUnitDigitalDocumentChild} = 0;
    $loanUnit->{numUnitOtherDigitalDocumentAdult} = 0;
    $loanUnit->{numUnitOtherDigitalDocumentChild} = 0;
}

sub initFundHashs{
    my $printedBook = shift;
    my $printedSerial = shift;
    my $audioVisual = shift;
    my $electronicSerial = shift;
    my $electronicBook = shift;
    my $otherDocument = shift;
    my $electronicOther = shift;
    my $otherSerial     = shift;

    $printedBook->{numAdultTitle} = 0;
    $printedBook->{numAdultUnit} = 0;
    $printedBook->{numChildTitle} = 0;
    $printedBook->{numChildUnit} = 0;
    $printedBook->{numNocodedTitle} = 0;
    $printedBook->{numNocodedUnit} = 0;
    $printedBook->{numPubEng} = 0;
    $printedBook->{numPubFr} = 0;
    $printedBook->{numPubOther} = 0;
    $printedBook->{numPubQuc} = 0;

    $printedSerial->{numAdultTitle} = 0;
    $printedSerial->{numAdultUnit} = 0;
    $printedSerial->{numChildTitle} = 0;
    $printedSerial->{numChildUnit} = 0;
    $printedSerial->{numNocodedUnit} = 0;
    $printedSerial->{numNocodedTitle} = 0;
    $printedSerial->{numPubQuc} = 0;

    $audioVisual->{numSRBookProdQuc} = 0;
    $audioVisual->{numSRBookTitle} = 0;
    $audioVisual->{numSRBookUnit} = 0;
    $audioVisual->{numSRCombProdQuc} = 0;
    $audioVisual->{numSRCombTitle} = 0;
    $audioVisual->{numSRCombUnit} = 0;
    $audioVisual->{numSRMusicProdQuc} = 0;
    $audioVisual->{numSRMusicTitle} = 0;
    $audioVisual->{numSRMusicUnit} = 0;
    $audioVisual->{numSRGameProdQuc} = 0;
    $audioVisual->{numSRGameTitle} = 0;
    $audioVisual->{numSRGameUnit} = 0;

    $electronicSerial->{numTitle} = 0;
    $electronicSerial->{numProdQuc} = 0;

    $electronicBook->{numTitle} = 0;
    $electronicBook->{numProdQuc} = 0;
    $electronicBook->{numItem} = 0;
    $electronicBook->{numItemQuc} = 0;

    $electronicOther->{numTitle} = 0;
    $electronicOther->{numProdQuc} = 0;

    $otherDocument->{numUnit} = 0;
    $otherDocument->{numProdQuc} = 0;
}


sub initAcquisitionHashs{
    my $printedBook = shift;
    my $printedSerial = shift;
    my $audioVisual = shift;
    my $docAcquired = shift;
    my $electronicBook = shift;
    my $electronicSerial = shift;
    my $electronicOther = shift;

    $printedBook->{numProdQucAcq} = 0;
    $printedBook->{numProdQucOutAcq} = 0;
    $printedBook->{numUnitAcq} = 0;
    $printedBook->{numUnitOutAcq} = 0;

    $printedSerial->{numTitle} = 0;
    $printedSerial->{numUnit} = 0;
    $printedSerial->{numPubQuc} = 0;

    $electronicBook->{numTitle} = 0;
    $electronicBook->{numItem} = 0;
    $electronicBook->{numItemAcq} = 0;
    $electronicBook->{numTitleQuc} = 0;
    $electronicBook->{numItemQuc} = 0;
    $electronicBook->{numItemAcqQuc} = 0;

    $electronicSerial->{numTitle} = 0;
    $electronicSerial->{numTitleQuc} = 0;
    $electronicSerial->{numUnit} = 0;
    $electronicSerial->{numUnitQuc} = 0;

    $electronicOther->{numTitle} = 0;
    $electronicOther->{numTitleQuc} = 0;
    $electronicOther->{numItem} = 0;
    $electronicOther->{numItemQuc} = 0;

    $audioVisual->{numUnitOutAcq} = 0;
    $audioVisual->{numUnitAcq} = 0;

    $docAcquired->{numTitleDerivation} = 0;
    $docAcquired->{numTitleOriginal} = 0;
}

sub getNumUsersFromReferenceYearAndCategorytype{
    my $refYear = shift;
    my $types_ref = shift;
    my @types = @{$types_ref};
    my $date = "$refYear-12-31";

    my $dbh = C4::Context->dbh;

    my $placeholders = join ", ", ("?") x @types;

    my $query = "SELECT count(*) FROM borrowers
LEFT JOIN categories ON borrowers.categorycode = categories.categorycode
WHERE DATE(dateexpiry)>=? AND
YEAR(dateenrolled) <= ? AND
category_type IN ($placeholders)";
    my $sth = $dbh->prepare($query);
    $sth->execute($date,$refYear,@types);
    my $count = $sth->fetchrow;

    return ($count);
}

sub getNumUsersFromReferenceYearAndSex{
    my $refYear = shift;
    my $sex = shift;
    my $date = "$refYear-12-31";

    my $dbh = C4::Context->dbh;
    my $query = "SELECT count(*) FROM borrowers WHERE DATE(dateexpiry)>=? AND sex=? AND YEAR(dateenrolled) <= ?";
    my $sth = $dbh->prepare($query);
    $sth->execute($date,$sex, $refYear);
    my $count = $sth->fetchrow;

    return ($count);
}

sub getNumActivesUsersFromReferenceYear{
    my $refYear = shift;
    my $date = "$refYear-12-31";

    my $dbh = C4::Context->dbh;
    my $query = "SELECT COUNT(DISTINCT borrowers.borrowernumber) FROM borrowers
LEFT JOIN issues ON borrowers.borrowernumber = issues.borrowernumber
LEFT JOIN old_issues ON borrowers.borrowernumber = old_issues.borrowernumber
WHERE YEAR(issues.issuedate) = ? OR YEAR(old_issues.issuedate) = ?
AND YEAR(borrowers.dateenrolled) <= ?
AND DATE(dateexpiry)>=?";
    my $sth = $dbh->prepare($query);
    $sth->execute($refYear, $refYear, $refYear, $date);
    my $count = $sth->fetchrow;

    return ($count);
}

sub getNumIssuesFromReferenceYearAndCategoryTypeAndBiblionumber{
    my $biblionumber = shift;
    my $refYear = shift;
    my $types_ref = shift;
    my @types = @{$types_ref};

    my $dbh = C4::Context->dbh;
    my $placeholders = join ", ", ("?") x @types;

    my $query = "SELECT count(*) FROM statistics
LEFT JOIN items USING(itemnumber)
LEFT JOIN borrowers USING(borrowernumber)
LEFT JOIN categories ON categories.categorycode=borrowers.categorycode
WHERE statistics.type IN ('issue','renew') AND
YEAR(statistics.datetime) = ? AND
items.biblionumber IS NOT NULL AND
items.biblionumber = ? AND
category_type IN ($placeholders)";
    my $sth = $dbh->prepare($query);
    $sth->execute($refYear,$biblionumber,@types);
    my $countbiblio = $sth->fetchrow;

    $query = "SELECT count(*) FROM statistics
LEFT JOIN deleteditems USING(itemnumber)
LEFT JOIN borrowers USING(borrowernumber)
LEFT JOIN categories ON categories.categorycode=borrowers.categorycode
WHERE statistics.type IN ('issue','renew') AND
YEAR(statistics.datetime) = ? AND
deleteditems.biblionumber IS NOT NULL AND
deleteditems.biblionumber = ? AND
category_type IN ($placeholders)";
    $sth = $dbh->prepare($query);
    $sth->execute($refYear,$biblionumber,@types);
    my $countdeletedbiblio = $sth->fetchrow;

    return ($countbiblio + $countdeletedbiblio);

}

sub isDigitalDocument{
    my $record = shift;

    my $field008 = $record->field('008');
    my $leader = $record->leader();
    if ($field008 && $leader){
        my $field008Data = $field008->data();
        if (substr($leader, 6, 1) eq 'a' && substr($leader, 7, 1) eq 's' &&
            (substr($field008Data, 23, 1) eq 's' || substr($field008Data, 23, 1) eq 'o')){
                return 1;
            }
    }
    my $field007 = $record->field('007');
    if ($field008 && $field007 && $leader){
        my $field008Data = $field008->data();
        my $field007Data = $field007->data();

        if (substr($leader, 6, 1) eq 'a' && substr($leader, 7, 1) eq 's' &&
            (substr($field008Data, 23, 1) eq 's' || substr($field008Data, 23, 1) eq 'o') &&
            !(substr($field007Data, 0, 1) eq 'c' && substr($field007Data, 1, 1) eq 'o')){
                return 1;
            }
    }

    return 0;
}
sub isElecBook{
    my $record = shift;
    my $leader = $record->leader();
    my $field007 = $record->field('007');
    my $field008 = $record->field('008');
    my $isElecBook;

    if ($field008 && $field007 && $leader){
        my $field008Data = sprintf "%-40s", $field008->data();
        my $field007Data = $field007->data();
        my $matchingLeader = substr($leader, 6, 1) eq 'a' && substr($leader, 7, 1) eq 'm' ;
        my $matching007 = !( substr($field007Data, 0, 1) eq 'c' && substr($field007Data, 1, 1) eq 'o' );
        my $matching008 = substr($field008Data, 23, 1) eq 's' || substr($field008Data, 23, 1) eq 'o';
        $isElecBook = $matchingLeader && $matching007 && $matching008;
    }
    return $isElecBook;
}
sub isElecSerial{
    my $record = shift;
    my $field008 = $record->field('008');
    my $leader = $record->leader();
    my $isElecSerial;

    if ($field008 && $leader){
        my $field008Data = sprintf "%-40s", $field008->data();
        my $matchingLeader = substr($leader, 6, 1) eq 'a' && substr($leader, 7, 1) eq 's';
        my $matching008 = substr($field008Data, 23, 1) eq 's' || substr($field008Data, 23, 1) eq 'o';
        $isElecSerial = $matchingLeader && $matching008;
    }

    return $isElecSerial;
}
sub isElecOther{
    my $record = shift;
    my $leader = $record->leader();
    my $field007 = $record->field('007');
    my $field008 = $record->field('008');
    my $isElecOther;

    if ($field008 && $field007 && $leader){
        my $field008Data = sprintf "%-40s", $field008->data();
        my $field007Data = $field007->data();
        my $matchingLeader = substr($leader, 6, 1) eq 'a' && substr($leader, 7, 1) ne 'm' && substr($leader, 7, 1) ne 's';
        my $matching007 = !( substr($field007Data, 0, 1) eq 'c' && substr($field007Data, 1, 1) eq 'o' );
        my $matching008 = substr($field008Data, 23, 1) eq 's' || substr($field008Data, 23, 1) eq 'o';
        $isElecOther = $matchingLeader && $matching007 && $matching008;
    }
    return $isElecOther;
}
sub isQuc{
    my $record = shift;
    my $field008 = $record->field('008');
    my $field008data = sprintf "%-40s", $field008->data() if $field008;
    my $quc = substr($field008data,15,3) eq 'quc' if $field008data;
    return $quc;
}

sub getNumProdQuc{
    my $record = shift;
    my $numItems = shift;
    my $totItemsQuebec = shift;

    my $field008 = $record->field('008');
    if ($field008){
        my $field008Data = sprintf "%-40s", $field008->data();

        #extract the number of publication units in quebec
        if (substr($field008Data,15,3) eq 'quc') {
            ${$totItemsQuebec} += $numItems;
        }
    }
}

sub getNumItemsUntilReferenceYear{
    my $biblionumber = shift;
    my $year = shift;

    my $dbh = C4::Context->dbh;

    my $queryDeleted = 'SELECT count(*) FROM  deleteditems WHERE biblionumber = ? and YEAR(dateaccessioned) <= ? and YEAR(timestamp) > ?';
    my $queryItems   = 'SELECT count(*) FROM  items WHERE biblionumber = ? and YEAR(dateaccessioned) <= ?';
    my $query = "SELECT ($queryDeleted) + ($queryItems)";

    my $count = shift $dbh->selectcol_arrayref( $query, undef, ($biblionumber, $year, $year, $biblionumber, $year) );

    return $count;
}

sub getNumItemsFromReferenceYearAndBiblionumber{
    my $Biblionumber = shift;
    my $refYear = shift;

    my $dbh = C4::Context->dbh;
    my $query = "SELECT count(*) FROM  items WHERE biblionumber=? and YEAR(dateaccessioned) = ?";
    my $sth = $dbh->prepare($query);
    $sth->execute($Biblionumber, $refYear);
    my $countitems = $sth->fetchrow;

    $query = "SELECT count(*) FROM  deleteditems WHERE biblionumber=? and YEAR(dateaccessioned) = ? and YEAR(timestamp)>?";
    $sth = $dbh->prepare($query);
    $sth->execute($Biblionumber, $refYear, $refYear);
    my $countdeleteditems = $sth->fetchrow;

    return ($countitems+$countdeleteditems);
}

sub getNumOrdersFromReferenceYearAndBiblionumber{
    my $Biblionumber = shift;
    my $refYear = shift;

    my $dbh   = C4::Context->dbh;
    my $query  = "SELECT sum(aqorders.quantity) FROM aqorders
            LEFT JOIN biblio           ON biblio.biblionumber = aqorders.biblionumber
            WHERE   aqorders.biblionumber=? and YEAR(aqorders.entrydate) = ?";
    my $sth = $dbh->prepare($query);
    $sth->execute($Biblionumber, $refYear);
    my $sum = $sth->fetchrow;
    if ($sum){
        return ($sum);
    } else {
        return 0;
    }
}


sub isPrintedBook{
    my $record = shift;

    my $leader = $record->leader();
    if ($leader){
        my $logTerm = 0; #if not 008 the first condition is false (excel G4)
        my $field008 = $record->field('008');
        if ($field008){
            my $pouet = sprintf "%-40s", $field008->data();
            my $z008_24 = substr($pouet,23,1);
            $logTerm = index("abcoqs", $z008_24) == -1;
        }

        if ((substr($leader, 6, 1) eq 'a' && substr($leader, 7, 1) eq 'm' && ($logTerm))
             || substr($leader, 6, 1) eq 'c' || substr($leader, 6, 1) eq 'd') {
            return 1;
        }
    }
    return 0;
}

sub isPrintedSerial{
    my $record = shift;

    my $field008 = $record->field('008');
    my $leader = $record->leader();
    if ($field008 && $leader){
        my $pouet = sprintf "%-40s", $field008->data();
        my $z008_24 = substr($pouet,23,1);
        my $logTerm = index("soq", $z008_24) == -1;
        if (substr($leader, 6, 1) eq 'a' && substr($leader, 7, 1) eq 's' && $logTerm){
            return 1;
        }
    }
    return 0;
}

sub isAudioVisual{
    my $record = shift;
    my $isAudioVisual = 0;
    my $field007 = $record->field('007');
    my $field008 = $record->field('008');
    my $leader = $record->leader();
    if ($field007 && $leader){
        my $field007Data = $field007->data();
        # audio visual CD music
        if (substr($leader, 6, 1) eq 'j' && substr($field007Data, 0, 1) eq 's' && substr($field007Data, 1, 1) eq 'd'){
            $isAudioVisual = 1;
        }

        # audio visual CD recorded books
        if (substr($leader, 6, 1) eq 'i' && substr($field007Data, 0, 1) eq 's' && substr($field007Data, 1, 1) eq 'd'){
            $isAudioVisual = 1;
        }
    }

    my $logTerm1 = 0; #if not 007 the first and second condition is false (excel G40 and H40)
    my $logTerm2 = 0; #if not 008 the third condition is false (excel I40)
    my $field007Data = 0;
    my $field008Data = 0;
    if ($field007 && $leader){
        $field007Data = $field007->data();
        $logTerm1 = substr($leader, 6, 1) eq 'g' && substr($field007Data, 0, 1) eq 'v' && substr($field007Data, 1, 1) eq 'd';
    }

    if ($field008 && $leader){
        $field008Data = sprintf "%-40s", $field008->data();
        $logTerm2 = substr($leader, 6, 1) eq 'm' && substr($field008Data, 26, 1) eq 'g';
    }

    # audio visual DVD Blue-ray video game
    if ($logTerm1 || $logTerm2){
        $isAudioVisual = 1;
    }
    return $isAudioVisual;
}

sub isAdultBook {
    my $record = shift;
    return _isTargetAudience( $record, [qw|e f g|], []);#qw|A A+ P|] );
}
sub isChildrenBook {
    my $record = shift;
    return _isTargetAudience( $record, [qw|a b c d j|], [qw|M E E+ E++ J J+ J++|] );
}
sub _isTargetAudience {
    my ($record, $match008, $match521a) = @_;
    my $isForAudience;
    if( my $field008 = $record->field('008') ){
        my @field008Data = split( '', sprintf "%-40s", $field008->data() ) ;
        $isForAudience = grep {/\Q$field008Data[22]\E/} @$match008;
    }
    if( !$isForAudience && ( my $field521 = $record->field('521') ) ){
        my $subfieldsA = $field521->subfield('a');
        my $regex_521a = join('|', @$match521a);
        $isForAudience = $subfieldsA =~ qr|/$regex_521a/i|;
    }

    return $isForAudience;
}
sub getNumSubscriptionFromReferenceYearAndBiblionumber {
    my ($biblionumber, $refYear) = @_;

    my $dbh            = C4::Context->dbh;
    my $query          = "SELECT count(*) FROM subscription WHERE biblionumber=? AND ( YEAR(startdate)<=? AND YEAR(enddate)>=? )";
    my $sth            = $dbh->prepare($query);
    $sth->execute($biblionumber, $refYear, $refYear);
    my $subscriptionsnumber = $sth->fetchrow;
    return $subscriptionsnumber;
}

sub getGetRenewalsFromReferenceYear {
    my ($refYear) = @_;
    my $dbh            = C4::Context->dbh;
    my $query          = "SELECT count(*) FROM statistics WHERE type='renew' and year(datetime) = ?";
    my $count          = $dbh->selectcol_arrayref($query, undef,($refYear));
    return $count;
}
1;
