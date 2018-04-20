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

our $VERSION = 0.2;
our $metadata = {
	name            => 'MergeUsers',
	author          => 'David Bourgault',
	description     => 'Merge users',
	date_authored   => '2017-11-15',
	date_updated    => '2017-11-16',
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
		my @sources = ();

		for ( my $i = 1; $i <= $cgi->param('count'); $i = $i + 1 ) {
			if ( $cgi->param( 'source-' . $i ) ) {
				push @sources, $cgi->param( 'source-' . $i );
			}
		}

		$self->calculate(
			$cgi->param('target'),
			@sources
		);
	}
	elsif ( $cgi->param('action') eq 'merge' and $cgi->param('confirm') eq 'confirm' ) {
		$self->fusion(
			$cgi->param('target'),
			$cgi->param('sources')
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
	my @sources = @_ or undef;

	my $cgi = $self->{cgi};
	my $template = $self->tmpl;

	# Get target borrowernumber from cardnumber
	my $statement = $dbh->prepare("SELECT borrowernumber FROM borrowers WHERE cardnumber = ? ");
	$statement->execute($target);
	my @row = $statement->fetchrow_array;
	$target = $row[0];

	# Get source borrowernumbers from cardnumbers, keep as a comma-seperated string
	my $sourceNumberList = '';

	$statement = $dbh->prepare("SELECT borrowernumber FROM borrowers WHERE cardnumber IN (" . ( "?," x (scalar @sources - 1)) . "?)");
	$statement->execute(@sources);

	@sources = ( );
	while ( my @row = $statement->fetchrow_array ) {
		push @sources, $row[0];
	}

	$sourceNumberList = join ',', @sources;

	# Calculate number of changes to database
	my %predictions = ( );
	$predictions{messages} = $dbh->selectrow_array("SELECT COUNT(*) FROM messages WHERE borrowernumber IN ($sourceNumberList);");
	$predictions{accountlines} = $dbh->selectrow_array("SELECT COUNT(*) FROM accountlines WHERE borrowernumber IN ($sourceNumberList);");
	$predictions{issues} = $dbh->selectrow_array("SELECT COUNT(*) FROM issues WHERE borrowernumber IN ($sourceNumberList);");
	$predictions{old_issues} = $dbh->selectrow_array("SELECT COUNT(*) FROM old_issues WHERE borrowernumber IN ($sourceNumberList);");
	$predictions{reserves} = $dbh->selectrow_array("SELECT COUNT(*) FROM reserves WHERE borrowernumber IN ($sourceNumberList);");
	$predictions{old_reserves} = $dbh->selectrow_array("SELECT COUNT(*) FROM old_reserves WHERE borrowernumber IN ($sourceNumberList);");
	$predictions{virtualshelves} = $dbh->selectrow_array("SELECT COUNT(*) FROM virtualshelves WHERE owner IN ($sourceNumberList);");

    $predictions{test_val} = $dbh->selectrow_array("SELECT * FROM deleteditems");

	$template->param( 
		predictions => \%predictions,
		target => $target,
		sources => $sourceNumberList
	);

	print $cgi->header(-type => 'text/html',-charset => 'utf-8');
	print $template->output();
}

sub fusion {
	my $self = shift;
	my $target = shift;
	my $sources = shift;

	my $cgi = $self->{cgi};
	my $template = $self->tmpl;

	# Remove references to borrowers
	my %actions = ( );
	$actions{messages} = $dbh->do("UPDATE messages SET borrowernumber=$target WHERE borrowernumber IN ($sources);");
	$actions{accountlines} = $dbh->do("UPDATE accountlines SET borrowernumber=$target WHERE borrowernumber IN ($sources);");
	$actions{issues} = $dbh->do("UPDATE issues SET borrowernumber=$target WHERE borrowernumber IN ($sources);");
	$actions{old_issues} = $dbh->do("UPDATE old_issues SET borrowernumber=$target WHERE borrowernumber IN ($sources);");
	$actions{reserves} = $dbh->do("UPDATE reserves SET borrowernumber=$target WHERE borrowernumber IN ($sources);");
	$actions{old_reserves} = $dbh->do("UPDATE old_reserves SET borrowernumber=$target WHERE borrowernumber IN ($sources);");
	$actions{virtualshelves} = $dbh->do("UPDATE virtualshelves SET owner=$target WHERE owner IN ($sources);");

	foreach my $k (keys %actions) {
		if ($actions{$k} eq '0E0') {
			$actions{$k} = 0;
		}
	}

	# Remove borrowers
	$dbh->do("DELETE FROM borrowers WHERE borrowernumber IN ($sources);");

	$template->param( 
		actions => \%actions,
	);

	print $cgi->header(-type => 'text/html',-charset => 'utf-8');
	print $template->output();
}

#Supprimer le plugin avec toutes ses données
sub uninstall() {
	my ( $self, $args ) = @_;
	#my $table = $self->get_qualified_table_name('mytable');
	return 0; #C4::Context->dbh->do("DROP TABLE $table");
}

1;
