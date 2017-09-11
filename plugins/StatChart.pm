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

my @graph_presets = (
	{ 
		id => 'graph-loans-dow',
		title_en => "Loans per day of the week", 
		title_fr => "Emprunts par jour de la semaine",
		type => "bar",
		query => "SELECT DAYOFWEEK(issuedate), DAYNAME(issuedate), COUNT(issuedate) FROM (SELECT issuedate FROM issues UNION SELECT issuedate FROM old_issues) AS all_issues GROUP BY DAYOFWEEK(issuedate);"
	},
	{ 
		id => 'graph-loans-itype',
		title_en => "Loans per document type", 
		title_fr => "Emprunts par type de document",
		type => "pie",
		query => "SELECT items.itype, itemtypes.description, COUNT(items.itype) FROM ((SELECT itemnumber FROM issues) UNION (SELECT itemnumber FROM old_issues)) as all_issues INNER JOIN items ON all_issues.itemnumber=items.itemnumber INNER JOIN itemtypes ON items.itype=itemtypes.itemtype GROUP BY items.itype ORDER BY COUNT(items.itype) DESC;"
	},
	{ 
		id => 'graph-loans-year',
		title_en => "Loans per years", 
		title_fr => "Emprunts par année",
		type => "bar",
		query => "SELECT YEAR(issuedate), YEAR(issuedate), COUNT(*) FROM (SELECT issuedate FROM issues UNION SELECT issuedate FROM old_issues) AS all_issues GROUP BY YEAR(issuedate) ORDER BY YEAR(issuedate) ASC;"
	}
);

my $locale = "en_US";

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
	$locale = $cgi->cookie('KohaOpacLanguage');
	
	my $template = $self->get_template( { file => "home.tt" } );

	$template->param(locale => substr($locale, 0, 2), graph_presets => \@graph_presets);
	print $cgi->header(-type => 'text/html',-charset => 'utf-8');
	print $template->output();
}

sub graph {
	my ( $self, $args) = @_;
	my $cgi = $self->{'cgi'};
	$locale = $cgi->cookie('KohaOpacLanguage');

	# Get all checked graphs
	my @graphs;
	for my $key ($cgi->param('graphs')) {
		for my $preset (@graph_presets) {
			if ($key eq $preset->{id}) {
				push @graphs, { type=> $preset->{type}, title => $preset->{'title_' . substr($locale, 0, 2)}, data => fetch($preset->{query})};

				# Graph with weekday as keys need some help :)
				if ($key eq 'graph-loans-dow') {
					$graphs[$#graphs]{data} = weekday_fixer(@{$graphs[$#graphs]{data}});
				}
			}
		}
	}
   
	my $template = $self->get_template( { file => "graph.tt" } );
	
	$template->param(locale => substr($locale, 0, 2), graphs => \@graphs);
	print $cgi->header(-type => 'text/html',-charset => 'utf-8');
	print $template->output();
}

# Fetch data from MySQL table
# The query must always return 3 values, a code for each value, a name for each value, 
# and the corresponding numerical value, in that order
sub fetch {
	my $query = shift;

	my @list;
	my $sql = $dbh->prepare( $query );
	$sql->execute();

	while(my @row = $sql->fetchrow_array) {
		push @list, {key => $row[0], name => $row[1], count => $row[2]};
	}
	
	return \@list;	
}

# Fixes datasets where the x-axis are weekdays.
# It does this in two ways : ensures all days are present even if the "count" is 0, and
# translates the dayname to the current locale
sub weekday_fixer {
	my @list = @_;

	my %dayname = (
		'en' => ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Sathurday'],
		'fr' => ['Dimanche', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi']
	);

	for my $i (0..6) {
		if ($list[$i]{key} != $i + 1) {
			splice @list, $i, 0, {key => $i + 1, name => $dayname{substr($locale, 0, 2)}[$i], count => 0};
		}
		else {
			$list[$i]{name} = $dayname{substr($locale, 0, 2)}[$i];
		}
	}
	return \@list;
}

#Supprimer le plugin avec toutes ses données
sub uninstall() {
	my ( $self, $args ) = @_;
	my $table = $self->get_qualified_table_name('mytable');

	return C4::Context->dbh->do("DROP TABLE $table");
}

1;
