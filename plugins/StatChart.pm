package Koha::Plugin::StatChart;

# David Bourgault, 2017 - Solutions inLibro
#
# Generates charts from various datasets, at user's request
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
use warnings;
use Data::Dumper;
use CGI;
use utf8;
use DateTime;
use base qw(Koha::Plugins::Base);
use C4::Auth;
use C4::Context;

our $VERSION  = 1.0;
our $metadata = {
    name            => 'StatChart',
    author          => 'David Bourgault',
    description     => 'Generates charts from various selectable datasets',
    date_authored   => '2017-09-11',
    date_updated    => '2017-09-11',
    minimum_version => '3.20',
    maximum_version => '17.05',
    version         => $VERSION,
};

# Presets
    # ID      : Unique identifier for coding purposes, never displayed
    # Type    : Chart type. Right now only the values 'bar', 'stacked' and 'pie' are supported. To support more types, you need to edit the javascript
    # yLabels : Data series names. NEEDS to be an array. Single values for 'bar' and 'pie', multiple for 'stacked'
    # query   : SQL Query to fetch data. First row should be the label of the x-axis (or categories in a pie chart), following rows should be data values.
    #           You should have as many columns as yLabels (so 1 for 'bar' or 'pie', multiple for 'stacked')
my @graph_presets = (
    {   id      => 'graph-loans-dow',
        type    => "bar",
        title   => "Loans per day of the week",
        ylabels => ["Loans"],
        query =>
            "SELECT DAYNAME(issuedate), COUNT(issuedate) FROM (SELECT issuedate FROM issues UNION SELECT issuedate FROM old_issues) AS all_issues GROUP BY DAYOFWEEK(issuedate);"
    },
    {   id      => 'graph-loans-itype',
        type    => "pie",
        title   => "Loans per document type",
        ylabels => ["Loans"],
        query =>
            "SELECT itemtypes.description, COUNT(items.itype) FROM ((SELECT itemnumber FROM issues) UNION (SELECT itemnumber FROM old_issues)) as all_issues INNER JOIN items ON all_issues.itemnumber=items.itemnumber INNER JOIN itemtypes ON items.itype=itemtypes.itemtype GROUP BY items.itype ORDER BY COUNT(items.itype) DESC;"
    },
    {   id      => 'graph-loans-year',
        type    => "bar",
        title   => "Loans per year",
        ylabels => ["Loans"],
        query =>
            "SELECT YEAR(issuedate), COUNT(*) FROM (SELECT issuedate FROM issues UNION SELECT issuedate FROM old_issues) AS all_issues GROUP BY YEAR(issuedate) ORDER BY YEAR(issuedate) ASC;"
    },
    {   id      => 'graph-transactions-year',
        type    => "stacked",
        title   => "Transactions per day of the week",
        ylabels => ["Checkouts", "Check-ins", "Renewals", "Reserves"],
        query =>
            "SELECT IFNULL(Weekday, 0), IFNULL(Checkouts,0), IFNULL(Returns,0), IFNULL(Renewals,0), IFNULL(Reserves,0) FROM (SELECT DAYOFWEEK(issuedate) AS dow, DAYNAME(issuedate) AS Weekday, COUNT(issuedate) AS Checkouts, COUNT(lastreneweddate) AS Renewals, COUNT(returndate) AS Returns FROM (SELECT * FROM issues UNION SELECT * FROM old_issues) AS all_issues GROUP BY DAYOFWEEK(issuedate)) AS issuestats LEFT JOIN (SELECT DAYOFWEEK(reservedate) AS dow, COUNT(reservedate) as Reserves FROM reserves GROUP BY DAYOFWEEK(reservedate)) AS restats ON issuestats.dow=restats.dow;"
    },
    {   id      => 'graph-items-type',
        type    => "pie",
        title   => "Items per type",
        ylabels => ["Items"],
        query =>
            "SELECT description, COUNT(itype) FROM items JOIN itemtypes ON items.itype=itemtypes.itemtype GROUP BY itype ORDER BY COUNT(itype) DESC;"
    },
    {   id      => 'graph-patron-categories',
        type    => "pie",
        title   => "Patrons per category",
        ylabels => ["Patrons"],
        query =>
            "SELECT categories.description, COUNT(borrowers.categorycode) FROM borrowers JOIN categories ON borrowers.categorycode=categories.categorycode GROUP BY borrowers.categorycode ORDER BY borrowers.categorycode ASC;"
    },
    {   id      => 'graph-transactions-hour',
        type    => "stacked",
        title   => "Transactions per hour of the day",
        ylabels => ["Checkouts", "Check-ins"],
        query =>
            "SELECT allhours.h, IFNULL(cout,0), IFNULL(chin, 0) FROM (SELECT 0 as h UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9 UNION ALL SELECT 10 UNION ALL SELECT 11 UNION ALL SELECT 12 UNION ALL SELECT 13 UNION ALL SELECT 14 UNION ALL SELECT 15 UNION ALL SELECT 16 UNION ALL SELECT 17 UNION ALL SELECT 18 UNION ALL SELECT 19 UNION ALL SELECT 20 UNION ALL SELECT 21 UNION ALL SELECT 22 UNION ALL SELECT 23) AS allhours LEFT JOIN (SELECT HOUR(issuedate) AS h, COUNT(*) as cout FROM (SELECT * FROM old_issues UNION SELECT * FROM issues) AS allissues GROUP BY HOUR(issuedate)) AS coutable ON coutable.h=allhours.h LEFT JOIN (SELECT HOUR(returndate) AS h, COUNT(*) as chin FROM old_issues GROUP BY HOUR(returndate)) AS chintable ON chintable.h=allhours.h;"
    },
    {   id      => 'graph-budgets',
        type    => "pie",
        title   => "Budget allocation",
        ylabels => ["Budget"],
        query => 
            "SELECT budget_period_description, budget_period_total FROM aqbudgetperiods ORDER BY budget_period_total DESC;"
    },
    {   id      => 'graph-items-branch',
        type    => "pie",
        title   => "Items per branch",
        ylabels => ["Items"],
        query => 
            "SELECT branchname, COUNT(*) FROM items JOIN branches ON items.homebranch=branches.branchcode;"
    },
    {   id      => 'graph-items-status',
        type    => "pie",
        title   => "Items per status",
        ylabels => ["Items"],
        query => 
            "SELECT lib, count(*) FROM items JOIN authorised_values AS av ON items.notforloan=av.authorised_value WHERE av.category='NOT_LOAN' GROUP BY lib;"
    },
    {   id      => 'graphs-items-location',
        type    => 'pie',
        title   => 'Items per location',
        ylabels => ['Items'],
        query =>
            "SELECT lib, COUNT(*) FROM items JOIN authorised_values AS av ON av.authorised_value=items.location WHERE av.category='LOC' GROUP BY lib;"
    },
    {   id      => 'graphs-accountlines-amount',
        type    => 'bar',
        title   => 'Amount per transaction type',
        ylabels => ['Amount'],
        query =>
            "SELECT de, SUM(amount) FROM accountlines LEFT JOIN (SELECT 'A' AS ty, 'Account management fee' AS de UNION SELECT 'C', 'Credit' UNION SELECT 'F', 'Overdue fine' UNION SELECT 'FOR', 'Forgiven' UNION SELECT 'FU', 'Overdue, still accruing' UNION SELECT 'L', 'Lost item' UNION SELECT 'LR', 'Lost item returned/refunded' UNION SELECT 'M', 'Sundry' UNION SELECT 'N', 'New card' UNION SELECT 'PAY', 'Payment' UNION SELECT 'W', 'Writeoff') AS descriptors ON accountlines.accounttype=descriptors.ty GROUP BY ty ORDER BY SUM(amount);"
    }        
);

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

    if ( $cgi->param('action') ) {
        $self->PageChart();
    }
    else {
        $self->PageHome();
    }
}

sub PageHome {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};
    my $locale = $cgi->cookie('KohaOpacLanguage');

    # Find locale-appropriate template
    my $template = undef;
    eval {$template = $self->get_template( { file => "home_" . $locale . ".tt" } )};
    if(!$template) {
        $locale = substr $locale, 0, 2;
        eval {$template = $self->get_template( { file => "home_$locale.tt" } )};
    }
    $template = $self->get_template( { file => 'home.tt' } ) unless $template;

    $template->param(graph_presets => \@graph_presets);
    print $cgi->header( -type => 'text/html', -charset => 'utf-8' );
    print $template->output();
}

sub PageChart {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};
    my $locale = $cgi->cookie('KohaOpacLanguage');

    # For every checked preset, build a graph and add it to the graph array
    my @graphs;
    for my $key ( $cgi->param('checkbox-preset') ) {
        for (my $i = 0; $i < @graph_presets; $i++) {
            if ( $key eq $graph_presets[$i]{id} ) {
                push @graphs, build_graph($graph_presets[$i]);
            }
        }
    }

    # Find locale-appropriate template
    my $template = undef;
    eval {$template = $self->get_template( { file => "chart_" . $locale . ".tt" } )};
    if(!$template) {
        $locale = substr $locale, 0, 2;
        eval {$template = $self->get_template( { file => "chart_$locale.tt" } )};
    }
    $template = $self->get_template( { file => 'chart.tt' } ) unless $template;

    $template->param(graphs => \@graphs);
    print $cgi->header( -type => 'text/html', -charset => 'utf-8' );
    print $template->output();
}

# Build the graph hash from the preset passed as param
sub build_graph {
    my $preset = shift;

    # Get the data from database
    # haha mysql
    my $sql = $dbh->prepare($preset->{query});
    $sql->execute();

    # Put data into arrays. The first column should contain labels for the x-axis (or categories if it's a pie chart)
    # If it doesn't, it's your problem, not mine.
    my @series;
    my @xlabels;
    my $i = 0;
    while ( my @row = $sql->fetchrow_array ) {
        $xlabels[$i] = $row[0];
        for (my $j = 1; $j < @row; $j++) {
            $series[$j - 1][$i] = $row[$j]
        }
        $i++;
    }

    # Return the hash
    return {
      id => $preset->{id},
      type => $preset->{type},
      title => $preset->{title},
      xlabels => \@xlabels,
      ylabels => $preset->{ylabels},
      series => \@series
    }
}

#Supprimer le plugin avec toutes ses données
sub uninstall() {
    my ( $self, $args ) = @_;
    my $table = $self->get_qualified_table_name('mytable');

    return C4::Context->dbh->do("DROP TABLE $table");
}

1;
