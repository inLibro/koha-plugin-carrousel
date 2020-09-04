#!/usr/bin/perl

# Copyright (c) 2013 inLibro
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;

use CGI;
use Mail::Sendmail;
use Encode;

use C4::Auth;    # get_template_and_user
use C4::Output;
use C4::Suggestions;
use C4::Members;
use Data::Dumper;
use Koha::DateUtils;
use Koha::Patrons;
use C4::Languages qw(getlanguage);

my $input           = new CGI;

my $type            = $input->param('type') || '';
my $chargedto       = $input->param('chargedto') || '';
my $maxcost         = $input->param('maxcost') || '';
my $approvedby      = $input->param('approvedby') || '';
my $booktitle       = $input->param('booktitle') || '';
my $serialtitle     = $input->param('serialtitle') || '';
my $author          = $input->param('author') || '';
my $pubyear         = $input->param('pubyear') || '';
my $isbn            = $input->param('isbn') || '';
my $publisher       = $input->param('publisher') || '';
my $artauthor       = $input->param('artauthor') || '';
my $year            = $input->param('year') || '';
my $volume          = $input->param('volume') || '';
my $number          = $input->param('number') || '';
my $pages           = $input->param('pages') || '';
my $article         = $input->param('article') || '';
my $status          = $input->param('status') || '';
my $op              = $input->param('op') || '';
$op = '' unless $op;

my ( $template, $borrowernumber, $cookie );

my $dbh = C4::Context->dbh;

my $lang = getlanguage($input);
if($lang eq "fr-CA" || $lang eq "fr-FR"){
    $lang = '_fr-CA';
}
else{
    $lang = "";
}

if(-f C4::Context->config("pluginsdir")."/Koha/Plugin/ILL/opac-ill$lang.tt"){
    ( $template, $borrowernumber, $cookie ) = get_template_and_user(
        {
            template_name   => C4::Context->config("pluginsdir")."/Koha/Plugin/ILL/opac-ill$lang.tt",
            query           => $input,
            type            => "opac",
            authnotrequired => 0,
            is_plugin       => 1,
        }
    );
}
else{
    ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name   => C4::Context->config("pluginsdir")."/Koha/Plugin/ILL/opac-ill.tt",
        query           => $input,
        type            => "opac",
        authnotrequired => 0,
        is_plugin       => 1,
    }
    );
}

my $patron = Koha::Patrons->find( $borrowernumber );

if ( $op eq "add_confirm" )
{
    #my $borr = GetMemberDetails( $borrowernumber );
    my $baseurl = C4::Context->preference("staffClientBaseURL");
    my $message ='';

        my $sth = $dbh->prepare( "INSERT INTO plugin_illrequest
                                 (borrowerid, type, chargedto, approvedby, maxcost, booktitle, serialtitle, author, pubyear, isbn, publisher, artauthor, year, volume, number, pages, article, status)
                                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)" );
        $sth->execute($borrowernumber, $type, $chargedto, $approvedby, $maxcost, $booktitle, $serialtitle, $author, $pubyear, $isbn, $publisher, $artauthor, $year, $volume, $number, $pages, $article, 'ASKED');

        $message .= '<html><head><style type="text/css">body{font-family: Verdana,Helvetica,sans-serif;font-size:12px} table.data{margin-bottom:1em;background-color:#F5E9FA;} span{font-size:12px;}.minlabel{font-weight:bold}.topborder{top-border: 1px solid red;} .label{width: 10em; font-weight:bold;} .serial{width:10em; font-weight:bold} td.datavue{font-size:12px;} .titletd{background-color: #CC352C; color:white; font-size:12px; font-weight:bold;}</style></head>';
        $message .= "<body>";
        $message .= "<table class='data'>";
        $message .= "<tr><td colspan=2 class='titletd'>Demandeur</td></tr>";
        $message .= "<tr>";
        $message .= "<td class='serial datavue'>Nom :</td>";
        $message .= "<td class='datavue'>" .
                "<a href='$baseurl/cgi-bin/koha/members/moremember.pl?borrowernumber=$borrowernumber'>" .
                ( $patron->{'title'}     ? encode( 'utf-8', $patron->{'title'} . ' ')      : '' ) .
                ( $patron->{'firstname'} ? encode( 'utf-8', $patron->{'firstname'} . ' ' ) : '' ) .
                ( $patron->{'surname'}   ? encode( 'utf-8', $patron->{'surname'} . ' ' )   : '' ) . "</a><br/></td>";
        $message .= "</tr>";
        $message .= "<tr>";
        $message .= "<td class='serial datavue'>T&#233;l&#233;phone :</td>";
        $message .= "<td class='datavue'>" . encode('utf-8', $patron->{'phone'} ) . '<br/>' if $patron->{'phone'};
        $message .= "</td></tr>";
        $message .= "<tr>";
        $message .= "<td class='serial datavue'>Courriel :</td>";
        $message .= "<td class='datavue'><a href='mailto:" . $patron->{'email'} ."'>"  . encode('utf-8', $patron->{'email'} ) . '</a><br/>' if $patron->{'email'};
        $message .= "</td></tr>";
        $message .= "<tr>";
        $message .= "<td class='serial datavue'>Service :</td>";
        $message .= "<td class='datavue'>"  . encode('utf-8', GetSortDetails( 'Services', $patron->{'sort1'} ) ) . '<br/>' if $patron->{'sort1'};
        $message .= "</td></tr>";
        $message .= "<tr>";
        $message .= "<td class='serial datavue'>Factur&#233; &#224; :</td>";
        $message .= "<td class='datavue'>$chargedto<br/>" if $chargedto;
        $message .= "</td></tr>";
        $message .= "<tr>";
        $message .= "<td class='serial datavue'>Co&#251;t maximum :</td>";
        $message .= "<td class='datavue'>$maxcost<br/>" if $maxcost;
        $message .= "</td></tr>";

        if ( $type eq "BOOK" )
        {
            $message .= "<tr><td colspan=2 class='titletd'>Livre</td></tr>";
            $message .= "<tr>";
            $message .= "<td class='label datavue'>Titre :</td><td class='datavue'>$booktitle<br/></td>";
            $message .= "</tr>";
            $message .= "<tr>";
            $message .= "<td class='label datavue'>Auteur :</td><td class='datavue'>$author<br/></td>";
            $message .= "</tr>";
            $message .= "<tr>";
            $message .= "<td class='label datavue'>Ann&#233;e :</td><td class='datavue'>$pubyear<br/></td>";
            $message .= "</tr>";
            $message .= "<tr>";
            $message .= "<td class='label datavue'>ISBN :</td><td class='datavue'>$isbn<br/></td>";
            $message .= "</tr>";
            $message .= "<tr>";
            $message .= "<td class='label datavue'>Editeur :</td><td class='datavue'>$publisher</td>";
            $message .= "</tr>";
            $message .= "<tr><td colspan=2 class='titletd'></td></tr>";
            $message .= "</table>";

        }

        if ( $type eq "SERIAL" )
        {

            $message .= "<tr><td colspan=2 class='titletd'>P&#233;riodique</td></tr>";
            $message .= "<tr>";
            $message .= "<td class='serial datavue'>Titre :</td><td class='datavue'> $serialtitle<br/></td>";
            $message .= "</tr>";
            $message .= "<tr>";
            $message .= "<td class='serial datavue'>Ann&#233;e :</td><td class='datavue'> $year, <span class='minlabel'>Volume :</span> $volume, <span class='minlabel'>No :</span> $number, <span class='minlabel'>Pages :</span> $pages<br/></td>";
            $message .= "</tr>";
            $message .= "<tr>";
            $message .= "<td class='serial datavue'>1er auteur :</td><td class='datavue'> $artauthor<br/></td>";
            $message .= "</tr>";
            $message .= "<tr>";
            $message .= "<td class='serial datavue'>Titre de l'article :</td><td class='datavue'> $article</td>";
            $message .= "</tr>";
            $message .= "<tr><td colspan=2 class='titletd'></td></tr>";
            $message .= "</table>";

        }

               $message .= "Acc&#233;der &#224; la <a href='http://$baseurl/cgi-bin/koha/plugins/run.pl?class=Koha::Plugin::ILL&method=tool&manage'>liste de PEB</a>";
               $message .= "</body></html>";

    my $lib = Koha::Libraries->find($patron->{'branchcode'});
    my $updateemailaddress = $lib->{'branchemail'};
    # Une regex de email parmi tant d'autres. Voir : http://regexlib.com/REDetails.aspx?regexp_id=3122
    $updateemailaddress = C4::Context->preference('KohaAdminEmailAddress') unless( $updateemailaddress =~ /^[0-9a-zA-Z]+([0-9a-zA-Z]*[-._+])*[0-9a-zA-Z]+@[0-9a-zA-Z]+([-.][0-9a-zA-Z]+)*([0-9a-zA-Z]*[.])[a-zA-Z]{2,6}$/);

    my %mail = (
        To      => $updateemailaddress,
        From    => $updateemailaddress,
        Subject => "Nouvelle demande de PEB",
        Body    => encode( 'ISO-8859-1', decode( "utf-8", $message ) ),#decode( 'utf-8', $message ),
        'Content-Type' => 'text/html; charset=utf-8',
    );

    if ( sendmail %mail ) {
        # do something if it works....
        warn "Mail sent ok\n";
    }
    else
    {
        # do something if it doesnt work....
        warn "Error sending mail: $Mail::Sendmail::error \n";
    }
}


if ( $op eq "delete_confirm" )
{
    my $sth_deleteRequest = $dbh->prepare("UPDATE plugin_illrequest SET status='CANCELLED' WHERE requestid = ? AND borrowerid = ?");

    my @deleteRequests = $input->param("deleteRequest");

    foreach my $requestid (@deleteRequests)
    {
        $sth_deleteRequest->execute($requestid, $borrowernumber);
    }
    $op = '';
}

if ( $op ne 'add')
{
    my $sth_bookrequests = $dbh->prepare("SELECT * FROM plugin_illrequest WHERE type='BOOK' AND borrowerid = ? AND ( status <> 'CANCELLED' AND status <> 'DELETED' ) order by date");
    $sth_bookrequests->execute($borrowernumber);
    my @books;

    if ( $sth_bookrequests->rows() )
    {
        my $even=0;
        while ( my $data = $sth_bookrequests->fetchrow_hashref)
        {
            $data->{date} = dt_from_string($data->{date});
            $data->{$data->{status}} = 1;
            $data->{even} = $even;
            $even = !$even;

            push @books, $data;
        }

        $op='else';
        $template->param( books => \@books);
    }

    my $sth_serialrequests = $dbh->prepare("SELECT * FROM plugin_illrequest WHERE type='SERIAL' AND borrowerid = ? AND status <> 'CANCELLED' order by date");
    $sth_serialrequests->execute($borrowernumber);
    my @serials;

    if ( $sth_serialrequests->rows() )
    {
        my $even=0;
        while ( my $data = $sth_serialrequests->fetchrow_hashref)
        {
                $data->{date} = dt_from_string($data->{date});
                $data->{$data->{status}} = 1;
                $data->{even} = $even;
                $even = !$even;

                push @serials, $data;
        }
        $op = 'else';
        $template->param( serials => \@serials);
    }

}

$template->param(

    #    suggestions_loop => $suggestions_loop,
    title  => $booktitle,
    author => $author,
    status => $status,
    patron => $patron,

    #    suggestedbyme    => $suggestedbyme,
    "op_$op" => 1,
    illview  => 1,
    OPAC_URL => "/plugin/Koha/Plugin/ILL/opac-ill.pl",
);

output_html_with_http_headers $input, $cookie, $template->output;
