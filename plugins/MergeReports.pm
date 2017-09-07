package Koha::Plugin::MergeReports;
# Dominic Pichette, 2017 - Inlibro
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

our $VERSION = 1.01;
our $metadata = {
    name            => 'MergeReports',
    author          => 'Dominic Pichette',
    description     => 'Merge multiple reports together',
    date_authored   => '2017-09-06',
    date_updated    => '2016-09-06',
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
        $self->mergeReports();
        #$self->go_home();
    }else{
        $self->step_1();
    }

}

sub step_1{
    my ( $self, $args) = @_;
    my $cgi = $self->{'cgi'};
    my $preferedLanguage = $cgi->cookie('KohaOpacLanguage');
    my @reports = $self->loadReports();
    my $template = undef;
    eval {$template = $self->get_template( { file => "step_1_" . $preferedLanguage . ".tt" } )};
    if(!$template){
        $preferedLanguage = substr $preferedLanguage, 0, 2;
        eval {$template = $self->get_template( { file => "step_1_$preferedLanguage.tt" } )};
    }
    $template = $self->get_template( { file => 'step_1.tt' } ) unless $template;
    $template->param( reports => \@reports);
    print $cgi->header(-type => 'text/html',-charset => 'utf-8');
    print $template->output();
}

sub loadReports{
    my ( $self, $args) = @_;
    my @reports;
    my $stmt = $dbh->prepare("select * from saved_sql");
    $stmt->execute();

    my $i =0;
    while (my $row = $stmt->fetchrow_hashref()) {
        $reports[$i] = $row;
        $i++;
    }
    return @reports;
}

sub mergeReports{
    my ( $self, $args) = @_;
    my $cgi = $self->{'cgi'};
    my @reportsId;
    my $stmt = $dbh->prepare("select * from saved_sql");
    $stmt->execute();
    my $i =0;
    while (my $row = $stmt->fetchrow_hashref()) {
        $reportsId[$i] = $row->{'id'};
        $i++;
    }
    my %runnedReports;
    foreach my $reportId (@reportsId){
        if ($cgi->param($reportId)){
            my $stmt = $dbh->prepare("select * from saved_sql where id=$reportId");
            $stmt->execute();           
            for my $row ($stmt->fetchrow_hashref()){
                my $fetchStmt = $dbh->prepare("$row->{'savedsql'}");
                my $reportName = $row->{'report_name'};
                $fetchStmt->execute();
                my @resultRows;
                my $j =0;
                while(my $resultRow = $fetchStmt->fetchrow_hashref()){
                    $resultRows[$j] = \$resultRow;
                }
                $runnedReports{$reportName} = \@resultRows;
                use Data::Dumper;
                warn Dumper(%runnedReports);
                #my $fields = $fetchStmt->{NAME};
                #my %hash;
                #my $#resultSet = @fields;
                #while( $resultSet = $sth->fetchrow_array() ) {
                #    my $j=0;
                #    foreach my $resultRow ($resultSet){
                #        $hash{ $item } = $fields[$j];
                #    }
                #}
                #$runnedReports{$reportName} = $fetchedRow;
                
            }
        }
    }
    $self->step_2(\%runnedReports);
}

sub step_2{
    my ( $self, $runnedReports) = @_;
    my $cgi = $self->{'cgi'};
    my $preferedLanguage = $cgi->cookie('KohaOpacLanguage');
    my $template = undef;
    eval {$template = $self->get_template( { file => "step_2_" . $preferedLanguage . ".tt" } )};
    if(!$template){
        $preferedLanguage = substr $preferedLanguage, 0, 2;
        eval {$template = $self->get_template( { file => "step_2_$preferedLanguage.tt" } )};
    }
    $template = $self->get_template( { file => 'step_2.tt' } ) unless $template;
    $template->param( results => $runnedReports);
    print $cgi->header(-type => 'text/html',-charset => 'utf-8');
    print $template->output();
 }


#Supprimer le plugin avec toutes ses données
sub uninstall() {
    my ( $self, $args ) = @_;
    my $table = $self->get_qualified_table_name('mytable');

    return C4::Context->dbh->do("DROP TABLE $table");
}

1;
