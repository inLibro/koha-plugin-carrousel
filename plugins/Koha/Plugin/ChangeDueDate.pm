package Koha::Plugin::ChangeDueDate;
# Mehdi Hamidi, 2016 - Inlibro
#
# This plugin allows you to generate a Carrousel of books from available lists
# and insert the template into the table system preferences;OpacMainUserBlock
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

our $VERSION = 1.11;
our $metadata = {
    name            => 'ChangeDueDate',
    author          => 'Mehdi Hamidi',
    description     => 'Change the return date of items using filters',
    date_authored   => '2016-06-08',
    date_updated    => '2016-06-08',
    minimum_version => '3.20',
    maximum_version => undef,
    version         => $VERSION,
};

our $dbh = C4::Context->dbh();
sub new {
    my ( $class, $args ) = @_;
    ## We need to add our metadata here so our base class can access it
    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;
    ## Here, we call the 'new' method for our base class
    ## This runs some additional magic and checking
    ## and returns our actual $self
    my $self = $class->SUPER::new($args);

    return $self;
}


sub tool {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    if ($cgi->param('action')){
        $self->changeDate();
        $self->go_home();
    }else{
        $self->step_1();
    }

}

sub step_1{
    my ( $self, $args) = @_;
    my $cgi = $self->{'cgi'};
    my $preferedLanguage = $cgi->cookie('KohaOpacLanguage');
    my @categories = $self->loadCategories();
    my @borrowers = $self->loadBorrowers();
    my @itemTypes = $self->itemTypes();
    my $template = undef;
    eval {$template = $self->get_template( { file => "step_1_" . $preferedLanguage . ".tt" } )};
    if(!$template){
        $preferedLanguage = substr $preferedLanguage, 0, 2;
        eval {$template = $self->get_template( { file => "step_1_$preferedLanguage.tt" } )};
    }
    $template = $self->get_template( { file => 'step_1.tt' } ) unless $template;
    
    $template->param( categories => \@categories, borrowers => \@borrowers, itemTypes => \@itemTypes);
    print $cgi->header(-type => 'text/html',-charset => 'utf-8');
    print $template->output();
}

sub loadBorrowers{
    my ( $self, $args) = @_;
    my @users;
    my $stmt = $dbh->prepare("select * from borrowers");
    $stmt->execute();

    my $i =0;
    while (my $row = $stmt->fetchrow_hashref()) {
        $users[$i] = $row;
        $i++;
    }
    return @users;
}

sub loadItems{
    my ( $self, $args) = @_;
    my @items;
    my $stmt = $dbh->prepare("select * from items");
    $stmt->execute();

    my $i =0;
    while (my $row = $stmt->fetchrow_hashref()) {
        $items[$i] = $row;
        $i++;
    }
    return @items;
}

sub loadCategories{
    my ( $self, $args) = @_;
    my @categories;
    my $stmt = $dbh->prepare("select * from categories");
    $stmt->execute();

    my $i =0;
    while (my $row = $stmt->fetchrow_hashref()) {
        $categories[$i] = $row;
        $i++;
    }

    return @categories;
}

sub itemTypes{
    my ( $self, $args) = @_;
    my @itemTypes;
    my $stmt = $dbh->prepare("select * from itemtypes");
    $stmt->execute();

    my $i =0;
    while (my $row = $stmt->fetchrow_hashref()) {
        $itemTypes[$i] = $row;
        $i++;
    }

    return @itemTypes;
}
sub changeDate{
    my ( $self, $args) = @_;
    my $cgi = $self->{'cgi'};
    my $category = $cgi->param('categories');
    my $itemType = $cgi->param('itemTypes');

    my $borrowerFrom = $cgi->param('borrowerFrom');
    my $borrowerTo = $cgi->param('borrowerTo');

    my $ExpecReturnFromDate = $cgi->param('ExpecReturnFromDate');
    my $ExpecReturnToDate = $cgi->param('ExpecReturnToDate');

    my $ExpecCheckoutFromDate = $cgi->param('ExpecCheckoutFromDate');
    my $ExpecCheckoutToDate = $cgi->param('ExpecCheckoutToDate');

    my $newTime = $cgi->param('newDate')." 23:59:59";
    my $newDate = $cgi->param('newDate');
    my @params;
    my $query = "update issues a INNER JOIN items b ON (a.itemnumber = b.itemnumber) inner join borrowers c on (a.borrowernumber = c.borrowernumber)  set a.date_due='$newTime', b.onloan ='$newDate'";

    if ( $ExpecCheckoutFromDate || $ExpecReturnFromDate || $category ne 'none' || $borrowerFrom || $itemType ne 'none'){

    }
    else{
        $self->go_home();
    }

    if($borrowerFrom && $borrowerTo){
        $query = $query." and a.borrowernumber between ? and ?";
        push @params, $borrowerFrom, $borrowerTo;
    }
    elsif($borrowerFrom){
        $query = $query." and a.borrowernumber=?";
        push @params, $borrowerFrom;
    }

    if($ExpecReturnFromDate && $ExpecReturnToDate){
        $query = $query." and CAST(a.date_due as Date) between ? and ?";
        push @params, $ExpecReturnFromDate, $ExpecReturnToDate;
    }
    elsif($ExpecReturnFromDate){
        $query = $query." and CAST(a.date_due as Date)=?";
        push @params, $ExpecReturnFromDate;
    }

    if($ExpecCheckoutFromDate && $ExpecCheckoutToDate){
        $query = $query." and CAST(a.issuedate as Date) between ? and ?";
        push @params, $ExpecCheckoutFromDate, $ExpecCheckoutToDate;
    }
    elsif($ExpecCheckoutFromDate){
        $query = $query." and  CAST(a.issuedate as Date)=?";
        push @params, $ExpecCheckoutFromDate;
    }

    $query = $query." and c.categorycode=?" unless $category eq 'none';
    push @params, $category unless $category eq 'none';

    $query = $query." and b.itype=?" unless $itemType eq 'none';
    push @params, $itemType unless $itemType eq 'none';

    #changer le premier and à un where 
    $query =~s/and/where/;
    my $stmt = $dbh->prepare($query);
    $stmt->execute(@params);

}

#Supprimer le plugin avec toutes ses données
sub uninstall() {
    my ( $self, $args ) = @_;
    my $table = $self->get_qualified_table_name('mytable');

    return C4::Context->dbh->do("DROP TABLE $table");
}

1;
