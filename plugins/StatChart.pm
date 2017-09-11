package Koha::Plugin::StatChart;
# David Bourgault, 2017 - Inlibro
#
# Generates charts from various datasets, at user's request
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
use DateTime;
use base qw(Koha::Plugins::Base);
use C4::Auth;
use C4::Context;

our $VERSION = 0.2;
our $metadata = {
	name            => 'StatChart',
	author          => 'David Bourgault',
	description     => 'Generates charts from various selectable datasets',
	date_authored   => '2017-09-08',
	date_updated    => '2017-09-11',
	minimum_version => '3.20',
	maximum_version => '17.05',
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
		$self->graph();
	} else {
		$self->home();
	}
}

sub home {
	my ( $self, $args) = @_;
	my $cgi = $self->{'cgi'};
	my $preferedLanguage = $cgi->cookie('KohaOpacLanguage');
	
	my $template = undef;
	eval {$template = $self->get_template( { file => "home_$preferedLanguage.tt" } )};
	$template = $self->get_template( { file => "home.tt" } ) unless $template;

	print $cgi->header(-type => 'text/html',-charset => 'utf-8');
	print $template->output();
}

sub graph {
	my ( $self, $args) = @_;
	my $cgi = $self->{'cgi'};
	my $preferedLanguage = $cgi->cookie('KohaOpacLanguage');

	my $loans = "";
	my @types = ();

	my @graphs = (0, 0);
	for my $key ($cgi->param('graphs')) {
		if ($key eq "loans-per-day") {
			$graphs[0] = 1;
			$loans = '[' . join(',',$self->fetchLoansPerDayOfWeek()) . ']';
		}
		if ($key eq "loans-per-type") {
			$graphs[1] = 1;
			@types = fetchIssuesPerItemType();
		}        
	}
   
	my $template = undef;

	eval {$template = $self->get_template( { file => "graph_$preferedLanguage.tt" } )};
	$template = $self->get_template( { file => "graph.tt" } ) unless $template;
	
	$template->param(graphs => \@graphs, loans => $loans, types => \@types);
	print $cgi->header(-type => 'text/html',-charset => 'utf-8');
	print $template->output();
}


sub fetchLoansPerDayOfWeek {
	my ( $self, $args) = @_;

	my @list = (0,0,0,0,0,0,0);
	my $sql = $dbh->prepare("SELECT UNIX_TIMESTAMP(issuedate) FROM issues UNION SELECT UNIX_TIMESTAMP(issuedate) FROM old_issues;");
	$sql->execute();

	while(my $row = $sql->fetchrow_array) {
		@list[(DateTime->from_epoch(epoch => $row))->day_of_week() % 7]++;
	}
	
	return @list;
}

sub fetchIssuesPerItemType {
	my ($self, $args) = @_;

	my @list;
	my $total;
	# haha my sql
	my $sql = $dbh->prepare("SELECT items.itype, itemtypes.description, COUNT(items.itype) FROM ((SELECT itemnumber FROM issues) UNION (SELECT itemnumber FROM old_issues)) as all_issues INNER JOIN items ON all_issues.itemnumber=items.itemnumber INNER JOIN itemtypes ON items.itype=itemtypes.itemtype GROUP BY items.itype ORDER BY COUNT(items.itype) DESC;");
	$sql->execute();

	while (my @row = $sql->fetchrow_array) {
		$total += $row[2];
		push @list, {code => $row[1], type => $row[1], count => $row[2]};
	}

	return @list;
}

#Supprimer le plugin avec toutes ses données
sub uninstall() {
	my ( $self, $args ) = @_;
	my $table = $self->get_qualified_table_name('mytable');

	return C4::Context->dbh->do("DROP TABLE $table");
}

1;
