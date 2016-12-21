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
use C4::Branch;
use Koha::DateUtils;

our $VERSION = 1.1;

our $metadata = {
    name   => 'Rules hard due dates',
    author => 'Bouzid Fergani',
    description => 'Rules hard due dates',
    date_authored   => '2016-12-20',
    date_updated    => '2015-12-20',
    minimum_version => '3.1406000',
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
     if ($op && $op eq 'valide'){
         my $preferedLanguage = $cgi->cookie('KohaOpacLanguage');
         my $template = undef;
         eval {$template = $self->get_template( { file => "rule_hard_due_date_$preferedLanguage.tt" }  )};
         if(!$template){
             $preferedLanguage = substr $preferedLanguage, 0, 2;
             eval {$template = $self->get_template( { file => "messaging_preference_wizard_$preferedLanguage.   tt" } )};
         }
         $template = $self->get_template( { file => 'rule_hard_due_date.tt' } ) unless $template;
         my $branchloop = &GetBranchs();
         &UpdateHardDueDate($branchcode,$harduedate,$addcancel);
         $template->param(
             branchloop => $branchloop,
             confirmation => 1,
         );
         print $cgi->header(-type => 'text/html',-charset => 'utf-8');
         print $template->output();
     }else{
         $self->show_config_pages();
     }
 }

 sub show_config_pages {
     my ( $self, $args) = @_;
     my $cgi = $self->{'cgi'};
     my $preferedLanguage = $cgi->cookie('KohaOpacLanguage');
     my $template = undef;
     eval {$template = $self->get_template( { file => "rule_hard_due_date_$preferedLanguage.tt" } )};
     if(!$template){
         $preferedLanguage = substr $preferedLanguage, 0, 2;
         eval {$template = $self->get_template( { file => "rule_hard_due_date_$preferedLanguage.tt" } )};
     }
     $template = $self->get_template( { file => 'rule_hard_due_date.tt' } ) unless $template;
     my $branchloop = &GetBranchs();
     $template->param(
         branchloop => $branchloop,
         confirmation  => 0,
     );
     print $cgi->header(-type => 'text/html',-charset => 'utf-8');
     print $template->output();
 }

 sub UpdateHardDueDate {
     my ($branchcode, $hardduedate, $addcancel) = @_;
     my $dbh   = C4::Context->dbh;
     my $issues_affected = 0;
     my $hard_due_date = ($addcancel eq 'add') ? $hardduedate : undef;
     my $sql = qq{
         UPDATE issuingrules
         SET hardduedate = ?, hardduedatecompare = ?
         WHERE branchcode = ?
     };
     my $sth = $dbh->prepare($sql);
     $sth->execute($hard_due_date,-1,$branchcode);
 }

sub GetBranchs {
    my $branches = GetBranches();
    my $branchloop;
    for my $thisbranch (sort { $branches->{$a}->{branchname} cmp $branches->{$b}->{branchname} } keys %{$branches}) {
        push @{$branchloop}, {
            value => $thisbranch,
            branchname => $branches->{$thisbranch}->{'branchname'},
        };
    }
    return $branchloop;
}

sub uninstall() {
     my ( $self, $args ) = @_;
     my $table = $self->get_qualified_table_name('mytable');

     return C4::Context->dbh->do("DROP TABLE $table");
 }

