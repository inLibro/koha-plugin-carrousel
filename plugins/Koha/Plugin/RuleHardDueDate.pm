package Koha::Plugin::RuleHardDueDate;

# Bouzid Fergani, 2016 - InLibro
#
# This plugin allow you to modify hard due date for selected branch and you can cancel it.
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under th
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

use base qw(Koha::Plugins::Base);

use CGI;
use C4::Context;
use Koha::DateUtils;
use C4::Members;
use C4::Koha;
use Koha::ItemTypes;
use Koha::Patron::Categories;

our $VERSION = 1.4;

our $metadata = {
    name   => 'Rules hard due dates',
    author => 'Bouzid Fergani, Maryse Simard',
    description => 'Rules hard due dates',
    date_authored   => '2016-12-20',
    date_updated    => '2021-02-12',
    minimum_version => '16.05',
    maximum_version => undef,
    version         => $VERSION,
};

sub new {
    my ( $class, $args ) = @_;
    $args->{'metadata'} = $metadata;
    my $self = $class->SUPER::new($args);
    return $self;
}

sub tool {
    my ( $self, $args ) = @_;

    my $cgi = $self->{'cgi'};
    my $op = $cgi->param('op');
    my $branchcode = $cgi->param('branch');
    my $harduedate = $cgi->param('duedate');
    my $addcancel = $cgi->param('addcancel');
    my $category = $cgi->param('category');
    my $itemtype = $cgi->param('itemtype');

    my $confirmation = 0;
    if ($op && $op eq 'valide'){
        &UpdateHardDueDate($branchcode,$harduedate,$addcancel,$category,$itemtype);
        $confirmation = 1;
    }

    $self->show_config_pages({ confirmation => $confirmation });
}

sub show_config_pages {
    my ( $self, $args) = @_;
    my $cgi = $self->{'cgi'};

    my $confirmation = $args->{confirmation} ? 1 : 0;
    my $branches   = Koha::Libraries->search({}, { order_by => "branchname" });
    my $categories = Koha::Patron::Categories->search();
    my $itemtypes  = Koha::ItemTypes->search({}, { order_by => "itemtype" });

    my $template = $self->retrieve_template({ name => "rule_hard_due_date" });
    $template->param(
        branches     => $branches,
        categories   => $categories,
        itemtypes    => $itemtypes,
        confirmation => $confirmation,
    );
    print $cgi->header(-type => 'text/html',-charset => 'utf-8');
    print $template->output();
}

sub UpdateHardDueDate {
    my ($branchcode, $hardduedate, $addcancel, $category, $itemtype) = @_;
    my $hard_due_date = ($addcancel eq 'add') ? $hardduedate : undef;

    # version actuelle
    my $kohaversion = C4::Context->preference("Version");
    $kohaversion =~ s/(.*\..*)\.(.*)\.(.*)/$1$2$3/;

    if ( $kohaversion < 19.1200018 ) {
        # la table issuingrules existe jusqu'à la version 19.12.00.018
        my $dbh = C4::Context->dbh;
        my $sql = qq{
            UPDATE issuingrules
            SET hardduedate = ?, hardduedatecompare = ?
        };
        my $where;
        my $wherebranch = ($branchcode eq "all") ? "" : " branchcode = '$branchcode'";
        $where = " WHERE $wherebranch" if $wherebranch;

        my $whereCat = ($category eq "all") ? "" : " categorycode = '$category'";
        #$wheres = ($where) ? $where : "";
        if ($where) {
            $where = ($whereCat) ? $where ." AND " . $whereCat : $where;
        } else {
            $where = ($whereCat) ? " WHERE $whereCat " : ''
        }

        my $whereItType = ($itemtype eq "all") ? "" : " itemtype = '$itemtype'";
        if ($where) {
            $where = ($whereItType) ? $where . " AND " . $whereItType : $where;
        } else {
            $where = ($whereItType) ? " WHERE $whereItType " : '';
        }

        $sql .= $where if ($where);
        my $sth = $dbh->prepare($sql);
        $sth->execute($hard_due_date,-1);
    } else {
        # Basé sur Koha::CirculationRules->set_rule
        my $params = {
            rule_name => ['hardduedate', 'hardduedatecompare'],
        };

        $params->{categorycode} = $category   eq '*' ? undef : $category   unless ( $category   eq "all" );
        $params->{branchcode}   = $branchcode eq '*' ? undef : $branchcode unless ( $branchcode eq "all" );
        $params->{itemtype}     = $itemtype   eq '*' ? undef : $itemtype   unless ( $itemtype   eq "all" );

        my $changed = 0;
        my $rules = Koha::CirculationRules->search( $params );
        while ( my $rule = $rules->next() ) {
            $changed++;
            if ( defined $hard_due_date ) {
                if ($rule->rule_name eq 'hardduedate') {
                    $rule->rule_value($hard_due_date);
                } elsif ($rule->rule_name eq 'hardduedate') {
                    $rule->rule_value(-1);
                }
                $rule->update();
            }
            else {
                $rule->delete();
            }
        }
    }
}

sub install {
    my ( $self, $params ) = @_;
    return 1;
}

sub uninstall {
    my ( $self, $params ) = @_;
    return 1;
}

=head3 retrieve_template

Retourne le template pour le nom fourni selon la langue.

=cut

sub retrieve_template {
    my ( $self, $params ) = @_;

    my $name = $params->{name} // "configure";

    # Le template dépend du cookie, celui par défault est anglais
    my $preferedLanguage = $self->{"cgi"}->cookie("KohaOpacLanguage") || "";
    my $template = undef;

    eval {$template = $self->get_template( { file => $name . "_$preferedLanguage.tt" } )};
    unless ( $template ) {
        $preferedLanguage = substr $preferedLanguage, 0, 2;
        eval {$template = $self->get_template( { file => $name . "_$preferedLanguage.tt" } )};
    }
    $template = $self->get_template( { file => "$name.tt" } ) unless ( $template );

    return $template;
}

1;
