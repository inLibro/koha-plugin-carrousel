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
use Date::Parse;
use DateTime;
use base qw(Koha::Plugins::Base);
use C4::Auth;
use C4::Context;

our $VERSION = 1.01;
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
    
    my $loans = '[' . join(',',$self->fetchLoansPerDayOfWeek()) . ']';
    my @types = fetchIssuesPerItemType();

    my $template = undef;
    eval {$template = $self->get_template( { file => "step_1_" . $preferedLanguage . ".tt" } )};
    if(!$template){
        $preferedLanguage = substr $preferedLanguage, 0, 2;
        eval {$template = $self->get_template( { file => "step_1_$preferedLanguage.tt" } )};
    }
    $template = $self->get_template( { file => 'step_1.tt' } ) unless $template;
    
    $template->param(loans => $loans, types => \@types);
    print $cgi->header(-type => 'text/html',-charset => 'utf-8');
    print $template->output();
}

sub fetchLoansPerDayOfWeek {
	my ( $self, $args) = @_;

	my @list = (0,0,0,0,0,0,0);
	my $sql = $dbh->prepare("SELECT issuedate FROM issues;");
	$sql->execute();

	while(my $row = $sql->fetchrow_array) {
		@list[(DateTime->from_epoch(epoch => str2time($row)))->day_of_week() % 7]++;
	}
	return @list;
}

sub fetchIssuesPerItemType {
	my ($self, $args) = @_;

	my @list;
	my $total;
	# haha my sql
	my $sql = $dbh->prepare("SELECT itemtypes.description, COUNT(items.itype) FROM issues INNER JOIN items ON issues.itemnumber=items.itemnumber INNER JOIN itemtypes ON items.itype=itemtypes.itemtype GROUP BY items.itype;");
	$sql->execute();

	while (my @row = $sql->fetchrow_array) {
		$total += $row[1];
		push @list, {type => $row[0], count => $row[1]};
	}

	# Sort array in decreasing amount of loans
	@list = sort {$b->{count} <=> $a->{count}} @list;

	# Remove me
	#for my $row (@list) { print "\t<tr>\n\t\t<td>$row->{type}</td>\n\t\t<td>$row->{count}</td>\n\t\t<td>",sprintf("%.2f", $row->{percent}),"</td>\n\t</tr>\n"; }
	return @list;
}

#Supprimer le plugin avec toutes ses données
sub uninstall() {
    my ( $self, $args ) = @_;
    my $table = $self->get_qualified_table_name('mytable');

    return C4::Context->dbh->do("DROP TABLE $table");
}

1;
