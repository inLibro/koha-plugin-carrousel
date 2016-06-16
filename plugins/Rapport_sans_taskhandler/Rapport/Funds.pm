# Copyright 2015 Solutions inLibro

use Modern::Perl;
package Koha::Plugin::Rapport::Funds;
## Required for all plugins
#use Koha::Plugin::Rapport::Tools;
use FindBin;
use lib $FindBin::Bin;
use Tools;

sub fundsPrintedBook{
    my $record = shift;
    my $numItems = shift;
    my $params = shift;
    my %printedBook = %$params;

    if (Koha::Plugin::Rapport::Tools::isPrintedBook($record)){
            #check if field 008 exists
            my $field008 = $record->field('008');
            if ($field008) {
                my $field008Data = sprintf "%-40s", $field008->data();
                #extract the number of adult units and title
                if(Koha::Plugin::Rapport::Tools::isAdultBook($record)){
                    $printedBook{numAdultTitle}++;
                    $printedBook{numAdultUnit} += $numItems;
                } elsif (Koha::Plugin::Rapport::Tools::isChildrenBook($record)){ #extract number of child units and title
                    $printedBook{numChildTitle}++;
                    $printedBook{numChildUnit} += $numItems;
                } else { #extract number of other units and title
                    $printedBook{numNocodedTitle}++;
                    $printedBook{numNocodedUnit} += $numItems;
                }

                #extract the number of publication units in french
                if (substr($field008Data,35,3) eq 'fre'){
                    $printedBook{numPubFr} += $numItems;
                } elsif (substr($field008Data,35,3) eq 'eng') { #extract the number of publication units in english
                    $printedBook{numPubEng} += $numItems;
                } else {
                    $printedBook{numPubOther} += $numItems;
                }

                #extract the number of publication units in quebec
                if (substr($field008Data,15,3) eq 'quc') {
                    $printedBook{numPubQuc} += $numItems;
                }
            } else { #no 008 field
                $printedBook{numTitleOut008} += $numItems;
            }
    }
    return \%printedBook
}

sub fundsPrintedSerial{
    my $record = shift;
    my $numItems = shift;
    my $params = shift;
    my %printedSerial = %$params;

    if (Koha::Plugin::Rapport::Tools::isPrintedSerial($record)){
        my $field008 = $record->field('008');
        my $leader = $record->leader();
        my $field008Data = sprintf "%40s", $field008->data();

        #extract the number of adult units and title
        if(Koha::Plugin::Rapport::Tools::isAdultBook($record)){
            $printedSerial{numAdultTitle}++;
            $printedSerial{numAdultUnit} += $numItems;
        } elsif (Koha::Plugin::Rapport::Tools::isChildrenBook($record)) { #extract number of child units and title
             $printedSerial{numChildTitle}++;
             $printedSerial{numChildUnit} += $numItems;
        } else { #extract number of other units and title
             $printedSerial{numNocodedTitle}++;
             $printedSerial{numNocodedUnit} += $numItems;
        }

        #extract the number of publication units in quebec
        if (substr($field008Data,15,3) eq 'quc') {
            $printedSerial{numPubQuc} += $numItems;
        }
    }
    return \%printedSerial
}

sub fundsAudioVisual{
    my $record = shift;
    my $numItems = shift;
    my $params = shift;
    my %audioVisual = %$params;

    my $field007 = $record->field('007');
    my $field008 = $record->field('008');
    my $leader = $record->leader();
    if ($field007 && $leader){
            my $field007Data = $field007->data();
            # audio visual music
            if (substr($leader, 6, 1) eq 'j' && substr($field007Data, 0, 1) eq 's' && substr($field007Data, 1, 1) eq 'd'){

                #extract the number of units and title
                $audioVisual{numSRMusicTitle}++;
                $audioVisual{numSRMusicUnit} += $numItems;

                #extract the number of productions units in quebec
                if ($field008){
                    my $field008Data = sprintf "%-40s", $field008->data();
                    if (substr($field008Data,15,3) eq 'quc') {
                        $audioVisual{numSRMusicProdQuc} += $numItems;
                    }
                }
            }

            # audio visual recorded books
            if (substr($leader, 6, 1) eq 'i' && substr($field007Data, 0, 1) eq 's' && substr($field007Data, 1, 1) eq 'd'){

                #extract the number of units and title
                $audioVisual{numSRBookTitle}++;
                $audioVisual{numSRBookUnit} += $numItems;

                #extract the number of productions units in quebec
                if ($field008){
                    my $field008Data = sprintf "%-40s", $field008->data();
                    if (substr($field008Data,15,3) eq 'quc') {
                        $audioVisual{numSRBookProdQuc} += $numItems;
                    }
                }
            }
    }

    my $logTerm1 = 0; #if not 007 the first and second condition is false (excel G40 and H40)
    my $isVideoGame = 0;
    my $field007Data = 0;
    my $field008Data = 0;
    if ($field007 && $leader){
        $field007Data = $field007->data();
        $logTerm1 = substr($leader, 6, 1) eq 'g' && substr($field007Data, 0, 1) eq 'v' && substr($field007Data, 1, 1) eq 'd';
    }

    if ($field008 && $leader){
        $field008Data = sprintf "%-40s", $field008->data();
        $isVideoGame = substr($leader, 6, 1) eq 'm' && substr($field008Data, 26, 1) eq 'g';
    }

    # combined audio visual
    if ($logTerm1 || $isVideoGame){
        my $index = $isVideoGame ? 'Game' : 'Comb';
        #extract the number of units and title
        $audioVisual{"numSR${index}Title"}++;
        $audioVisual{"numSR${index}Unit"} += $numItems;

        #extract the number of productions units in quebec
        if ($field008Data){
            if (substr($field008Data,15,3) eq 'quc') {
                $audioVisual{"numSR${index}ProdQuc"} += $numItems;
            }
        }
    }
    return \%audioVisual
}

sub fundsElecSerial{
    my $record = shift;
    my $itemCnt = shift;
    my $params = shift;
    return _fundAbstract($record, $itemCnt, $params, \&Koha::Plugin::Rapport::Tools::isElecSerial);
}
sub fundsElecBook{
    my $record = shift;
    my $itemCnt = shift;
    my $params = shift;
    return _fundAbstract($record, $itemCnt, $params, \&Koha::Plugin::Rapport::Tools::isElecBook);
}
sub fundsElecOther{
    my $record = shift;
    my $itemCnt = shift;
    my $params = shift;
    return _fundAbstract($record, $itemCnt, $params, \&Koha::Plugin::Rapport::Tools::isElecOther);
}

sub _fundAbstract{
    my $record = shift;
    my $itemCnt = shift;
    my $params = shift;
    my $condition = shift;
    if ( $condition->($record) ){
        #extract the number of title
        $params->{numTitle}++;
        $params->{numItem} += $itemCnt;
        #extract the number of productions in quebec
        if ( Koha::Plugin::Rapport::Tools::isQuc($record) ) {
            $params->{numProdQuc}++;
            $params->{numItemQuc} += $itemCnt;
        }
    }
    return $params;
}

sub fundsOthers{
    my ($statistiquesFunds, $totItems, $totItemsQuebec) = @_;
    my %otherDocument = ();
    my $numUnit = 0;
    my $numProdQuc = 0;
    while ( my ($keyTmp, $hash) = each($statistiquesFunds) ) {
        while (my ($key, $value) = each($hash)) {
            if ($key =~ /Unit|Item/){
                $numUnit+=$value;
            }
            if (index($key, "Quc") != -1){
                $numProdQuc+=$value;
            }
        }
    }

    $otherDocument{numUnit} = $totItems - $numUnit;
    $otherDocument{numProdQuc} = $totItemsQuebec - $numProdQuc;

    return \%otherDocument;
}

1;
