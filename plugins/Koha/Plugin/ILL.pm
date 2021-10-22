package Koha::Plugin::ILL;
# Mehdi Hamidi, 2016 - InLibro
# Modified by Bouzid Fergani, 2016 - InLibro
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
use DBI;
use Template;
use C4::Auth;
use utf8;
use base qw(Koha::Plugins::Base);
use Data::Dumper;
use C4::NewsChannels;
use C4::Output;
use Koha::DateUtils;
use Encode;
use Mail::Sendmail;
use C4::Languages qw(getlanguage);


our $VERSION = 1.4;
our $metadata = {
    name            => 'ILL',
    author          => 'Charles Farmer, Alexis Ripetti',
    description     => 'Allow interlibrary loan requests',
    date_authored   => '2016-05-27',
    date_updated    => '2021-10-22',
    minimum_version => '3.20',
    maximum_version => undef,
    version         => $VERSION,
};

our $dbh = C4::Context->dbh();
our $input = new CGI;

my $table_name = 'plugin_illrequest';
my $first_line = "// Debut ILL //";
my $second_line ="// Fin ILL //";

sub new {
    my ( $class, $args ) = @_;
    $args->{'metadata'} = $metadata;
    my $self = $class->SUPER::new($args);
    return $self;
}

sub tool {

    #print $input->header(-type => 'text/html',-charset => 'utf-8');

    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    if (defined $cgi->param('manage')){
        $self->intranet_ill;
    }else{
        my $pref_value_intranet = q{
$(document).ready( function(){
    //Pour l'Intranet
    var langPref = $('html').attr('lang').substr(0, 2);
    var label;
    var description;
    if(langPref == 'fr'){
        label = 'Demandes PEB';
        description = 'Gérer vos demandes PEB';
    }else{
        label = 'ILL requests';
        description = 'Monitoring ILL requests';
    }
    $('.row .col-sm-4 dl').first().append("<dt><a href=\"/cgi-bin/koha/plugins/run.pl?class=Koha::Plugin::ILL&method=tool&manage\">" + label +"</a></dt><dd>" + description + "</dd>");
    });
        };

        my $pref_value_opac = q{
$(document).ready( function(){
    //Pour l'OPAC
    var langPref = $('html').attr('lang').substr(0, 2);
    var label;
    if(langPref == 'fr'){
        label = 'Mes PEB';
    }else{
        label = 'Your ILL';
    }
    $('#usermenu ul').append("<li><a href=\"/plugin/Koha/Plugin/ILL/opac-ill.pl\">" + label +"</a></li>");
    });
            };

        $self->create_tables() unless table_exist();
        insert_into_pref("IntranetUserJS",$pref_value_intranet);
        insert_into_pref("OPACUserJS",$pref_value_opac);
        $self->go_home();
    }
}


sub table_exist{
    my $exists;
    my @info;
    my $sth = $dbh->prepare("SELECT * from $table_name");
    $sth->execute();
    if($sth->fetch){
        warn "Table $table_name already exist";
        return 1;
    }
    warn "Table $table_name will be create";
    return 0;
}


sub create_tables{
    $| = 1;

    $dbh->do("CREATE TABLE `$table_name` (
        `requestid`     INT(8) NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `borrowerid`    INT(11) NOT NULL,
        `type`          VARCHAR(10) NOT NULL,
        `chargedto`     VARCHAR(80) NOT NULL,
        `approvedby`    VARCHAR(25) DEFAULT NULL,
        `maxcost`       VARCHAR(10) NOT NULL,
        `booktitle`     VARCHAR(80) NOT NULL,
        `serialtitle`   VARCHAR(80) DEFAULT NULL,
        `author`        VARCHAR(80) DEFAULT NULL,
        `pubyear`       VARCHAR(50) DEFAULT NULL,
        `isbn`          VARCHAR(30) DEFAULT NULL,
        `publisher`     VARCHAR(120) DEFAULT NULL,
        `artauthor`     VARCHAR(120) DEFAULT NULL,
        `year`          VARCHAR(15) DEFAULT NULL,
        `volume`        VARCHAR(15) DEFAULT NULL,
        `number`        VARCHAR(15) DEFAULT NULL,
        `pages`         VARCHAR(15) DEFAULT NULL,
        `article`       VARCHAR(15) DEFAULT NULL,
        `date`          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `status`        VARCHAR(10) DEFAULT NULL
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8");
    $dbh->do("INSERT INTO `systempreferences` VALUES ('InterLibraryLoans', '0', NULL, 'This parameter toggles if users are entitled to ask for an interlibrary loan', 'YesNo')");
}

sub insert_into_pref{
    my $variable = shift;
    my $prefData = shift;

    my $value;
    my $stmt = $dbh->prepare("SELECT * FROM systempreferences WHERE variable = ?");
    $stmt->execute($variable);
    while(my $row = $stmt->fetchrow_hashref){
        $value = $row->{'value'};
    }

    if(index($value, $first_line) == -1 && index($value, $second_line) == -1){
        $value .= "\n".$first_line.$prefData.$second_line;
    }else{
        #$value = $first_line.$prefData.$second_line;
        $value =~ s/$first_line.*?$second_line/$first_line$prefData$second_line/s;
    }
    my $query = $dbh->prepare("update systempreferences set value = ? where variable ='$variable'");
    $query->bind_param(1,$value);
    $query->execute();
    $query->finish();
    $stmt->finish();
}


sub intranet_ill{

    my ( $self, $args ) = @_;
    my ( $template, $borrowernumber, $cookie );

    $input = $self->{'cgi'};

    my $id             = $input->param('id');
    my $title          = $input->param('title');
    my $new            = $input->param('new');
    my $number         = $input->param('number');

    my $applyFilters = $input->param('applyfilters');

    my $changeStatus = $input->param('changeStatus') ne '';
    my $deleteSelection = $input->param('deleteSelected') ne '';

    my $new_detail = get_opac_new($id);

    my $lang = getlanguage($input);
    if($lang eq "fr-CA" or $lang eq "fr-FR"){
        $lang = '_fr-CA';
    }
    else{
        $lang = "";
    }

    if(-f C4::Context->config("pluginsdir")."/Koha/Plugin/ILL/ill$lang.tt"){
        ( $template, $borrowernumber, $cookie ) = get_template_and_user(
            {
                template_name   => C4::Context->config("pluginsdir")."/Koha/Plugin/ILL/ill$lang.tt",
                query           => $input,
                type            => "intranet",
                authnotrequired => 0,
                flagsrequired   => { tools => 'edit_news' },
                debug           => 1,
                is_plugin       => 1,
            }
        );
    }
    else{
        ( $template, $borrowernumber, $cookie ) = get_template_and_user(
        {
            template_name   => C4::Context->config("pluginsdir")."/Koha/Plugin/ILL/ill.tt",
            query           => $input,
            type            => "intranet",
            authnotrequired => 0,
            flagsrequired   => { tools => 'edit_news' },
            debug           => 1,
            is_plugin       => 1,
        }
        );
    }

    my $op = $input->param('op');

    my $sth_getRequest = $dbh->prepare("SELECT *, borrowers.email, borrowers.title, borrowers.firstname, borrowers.surname FROM $table_name LEFT JOIN borrowers ON $table_name.borrowerid = borrowers.borrowernumber WHERE $table_name.requestid = ?");

    my @selectedRequests = $input->param('selectRequest');

    if ( $changeStatus || $deleteSelection )
    {
        my $sth_changeStatus = $dbh->prepare("UPDATE $table_name SET status = ? WHERE requestid = ?");

        my $newStatus = $deleteSelection ? 'DELETED' : $input->param('newStatus');

        foreach my $requestid (@selectedRequests)
        {
            $sth_getRequest->execute($requestid);
            my $data = $sth_getRequest->fetchrow_hashref;

            if ( $data && ( $newStatus ne $data->{'status'} ) )
            {
                $sth_changeStatus->execute($newStatus, $requestid);

                # On récupère le nom de la branche pour signer l'email
                my $userenv_branch  = C4::Context->userenv->{'branch'} || '';
                my $branchname;
                if ($userenv_branch and my $library = Koha::Libraries->find($userenv_branch)) {
                    $branchname = $library->branchname;
                }

                my $message = '<p>Bonjour ' . ($data->{'title'} ? $data->{'title'} . ' ' : '' ) . $data->{'firstname'} . ' ' . $data->{'surname'}.'</p>';

                my $footer;
                my $proceedWithEmail = 1;
                if ( $newStatus eq 'ACCEPTED' )
                {
                    $message .= '<p>Ceci est un message pour vous mentionner que votre demande de PEB a été acceptée.</p>';

                    $footer = '<p>Vous recevrez un autre message lorsque nous aurons le document à la bibliothèque.</p>';
                }
                elsif ( $newStatus eq 'REJECTED' )
                            {
                                    $message .= '<p>Ceci est un message pour vous mentionner que votre demande de PEB a été rejetée.</p>';
                            }
                elsif ( $newStatus eq 'AVAILABLE' )
                {
                    $message .= '<p>Ceci est un message pour vous mentionner que le document que vous avez demandé lors de votre demande de PEB est arrivé à la bibliothèque.</p>';

                    $footer .= '<p>Vous pouvez venir le récupérer à votre convenance.</p>';
                }
                else
                {
                    $proceedWithEmail = 0;
                }

                            if ( $data->{'type'} eq 'BOOK' )
                            {
                                    $message .= '<b>Titre : </b> ' . $data->{'booktitle'}  . '<br/>'  if $data->{'booktitle'};
                                    $message .= '<b>Auteur : </b> ' . $data->{'author'} . '<br/>' if $data->{'author'};
                            }
                            else
                            {
                                    $message .= '<b>Date : </b>'. $data->{'year'} . '<br/>' if $data->{'year'};
                                    $message .= "<b>Titre de l'article : </b>" . $data->{'article'} . '<br/>' if $data->{'article'};
                                    $message .= "<b>Auteur de l'article : </b>" . $data->{'artauthor'} . '<br/>' if $data->{'artauthor'};
                            }

                $message .= $footer if $footer;
                if ($branchname) {
                    $message .= '<p>Cordialement,</p><p>'. $branchname  . '</p>';
                }
                else {
                    $message .= '<p>Cordialement.</p>';
                }

                if ( $proceedWithEmail )
                {
                    my $libraryemail = C4::Context->preference('KohaAdminEmailAddress');

                    my $toEmail = $data->{email};

                        my %mail = (
                                To      => $toEmail,
                                CC      => $libraryemail,
                                From    => $libraryemail,
                                Subject => encode("utf-8","Demand PEB - mise à jour"),
                                Message => encode('utf-8', $message),
                                'Content-Type' => 'text/html; charset="utf-8"',
                        );

                        if ( sendmail( %mail ) ) {
                                # do something if it works....
                                warn "Mail sent ok\n";
                        }
                }
            }
        }
    }

    my $statusFilters = '';
    if ($applyFilters)
    {
        my @filters = $input->param('filter');

        my $first = 1;
        foreach my $filter (@filters)
        {
            if ( !$first )
            {
                $statusFilters .= ' OR ';
            }

            $statusFilters .= "status = '$filter'";

            my $filtervalue = "filter".$filter;

            $template->param( $filtervalue => 1 );

            $first = 0;
        }
    }
    else
    {
        $template->param(filterASKED => 1);
        $template->param(filterACCEPTED => 1);
        $template->param(filterCANCELLED => 1);
        $template->param(filterORDERED => 1);
        $template->param(filterREJECTED => 1);
        $template->param(filterAVAILABLE => 1);
        $template->param(filterONLOAN => 1);

        $statusFilters = "status <> 'DELETED'";
    }


    my $sth_borrower = $dbh->prepare("SELECT title, firstname, surname FROM borrowers WHERE borrowernumber=?");

    my $fullquery = "SELECT * FROM $table_name WHERE type='BOOK' ". ($statusFilters ? "AND ($statusFilters)" : "") . " ORDER BY date";
    my $sth_bookrequests = $dbh->prepare("SELECT * FROM $table_name WHERE type='BOOK' ". ($statusFilters ? "AND ($statusFilters)" : "") . " ORDER BY date");
    $sth_bookrequests->execute();
    my @books;
    if ( $sth_bookrequests->rows() )
    {

            my $even=0;
            while ( my $data = $sth_bookrequests->fetchrow_hashref)
            {
            $sth_borrower->execute($data->{borrowerid});
            my ($title, $firstname, $surname) = $sth_borrower->fetchrow();

            $data->{borrower} = ( $title ? $title . ' ' : "" ) . "$firstname $surname";
                    $data->{date} = dt_from_string($data->{date});
                    $data->{$data->{status}} = 1;
                    $data->{even} = $even;
                    $even = !$even;

                    foreach my $request (@selectedRequests)
                    {
                            $data->{checked} = 1 if $data->{requestid} == $request;
                    }

                    push @books, $data;
            }

            $op='else';
            $template->param( books => \@books, hasrequests => 1);
    }

    my $sth_serialrequests = $dbh->prepare("SELECT * FROM $table_name WHERE type='SERIAL' " . ( $statusFilters ? "AND ( $statusFilters )" : "" ) . " ORDER BY date");
    $sth_serialrequests->execute();
    my @serials;

    if ( $sth_serialrequests->rows() )
    {

        #concatenate the selected request to grep them later.

        my $even=0;
        while ( my $data = $sth_serialrequests->fetchrow_hashref)
        {
        $sth_borrower->execute($data->{borrowerid});
        my ($title, $firstname, $surname) = $sth_borrower->fetchrow();

        $data->{borrower} = ($title ? $title . ' ' : '' ) . "$firstname $surname";
                $data->{date} = dt_from_string($data->{date});
                $data->{$data->{status}} = 1;
                $data->{even} = $even;
                $even = !$even;
        foreach my $request (@selectedRequests)
        {
            $data->{checked} = 1 if $data->{requestid} == $request;
        }

                push @serials, $data;
        }
        $op = 'else';
        $template->param( serials => \@serials, hasrequests => 1);
    }

    $template->param(
                class                    => 'Koha::Plugin::ILL',
                PLUGIN_PATH              => C4::Context->config("pluginsdir")."/Koha/Plugin/ILL",
                method                   => 'tool',
                manager                  => 'manage',
                applyfilters             => 1,
                showfilters              => $input->param('showfilters'),
                DHTMLcalendar_dateformat => '',#C4::Dates->DHTMLcalendar(),
            );
    output_html_with_http_headers( $input, $cookie, $template->output );
}

#Supprimer le plugin avec toutes ses données
sub uninstall() {
    $dbh->do("DROP TABLE `$table_name` CASCADE");
    my $stm = $dbh->prepare("DELETE FROM systempreferences WHERE variable = ?");
    $stm->execute('InterLibraryLoans');
    $stm->finish();

    #Fair ele ménage dans le javascript
    my ( $valueOpac, $valueIntra );
    $stm = $dbh->prepare("SELECT * FROM systempreferences WHERE variable = ?");

    $stm->execute("OPACUserJS");
    while(my $row = $stm->fetchrow_hashref){
        $valueOpac = $row->{'value'};
    }
    $valueOpac =~ s/$first_line.*?$second_line//s;

    $stm->execute("IntranetUserJS");
    while(my $row = $stm->fetchrow_hashref){
        $valueIntra = $row->{'value'};
    }
    $valueIntra =~ s/$first_line.*?$second_line//s;
    $stm->finish();

    my $query = $dbh->prepare("update systempreferences set value = ? where variable = ?");
    $query->execute($valueIntra,'IntranetUserJS');
    $query->execute($valueOpac,'OPACUserJS');
    $query->finish();
    $stm->finish();

    rmdir C4::Context->config("pluginsdir")."/Koha/Plugin/ILL";
}
;
