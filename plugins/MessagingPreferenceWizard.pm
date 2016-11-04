package Koha::Plugin::MessagingPreferenceWizard;


use Modern::Perl;

use base qw(Koha::Plugins::Base);

use C4::Context;
use C4::Branch;
use C4::Members;
use C4::Auth;
use C4::Members::Messaging;
use C4::Context;
use Pod::Usage;
use Getopt::Long;
use Data::Dumper;

our $VERSION = 1.1;

our $metadata = {
    name   => 'Enhanced messaging preferences wizard',
    author => 'Bouzid Fergani',
    description => 'Setup or reset the enhanced messaging preferences to default values',
    date_authored   => '2016-07-13',
    date_updated    => '2015-07-13',
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
    my $truncate = $cgi->param('trunc');
    my $since = $cgi->param('since');
    if ($op eq 'valide'){
        $since = '0000-00-00' if (!$since);
        warn $since;
        my $dbh = C4::Context->dbh;
        $dbh->{AutoCommit} = 0;
        if ( $truncate ) {
            my $sth = $dbh->prepare("TRUNCATE borrower_message_preferences");
            $sth->execute();
        }

        my $sth = $dbh->prepare("SELECT borrowernumber, categorycode FROM borrowers WHERE dateenrolled >= ?");
        $sth->execute($since);
        my $preferedLanguage = $cgi->cookie('KohaOpacLanguage');
        my $template = undef;
        eval {$template = $self->get_template( { file => "messaging_preference_wizard_$preferedLanguage.tt" } )};
        if(!$template){
            $preferedLanguage = substr $preferedLanguage, 0, 2;
            eval {$template = $self->get_template( { file => "messaging_preference_wizard_$preferedLanguage.tt" } )};
        }
        $template = $self->get_template( { file => 'messaging_preference_wizard.tt' } ) unless $template;
        while ( my ($borrowernumber, $categorycode) = $sth->fetchrow ) {
            C4::Members::Messaging::SetMessagingPreferencesFromDefaults( {
                borrowernumber => $borrowernumber,
                categorycode   => $categorycode,
            } );
        }
        $dbh->commit();
        $template->param( fin => 1);
        print $cgi->header();
        print $template->output();
    }else{
        $self->show_config_pages();
    }
}

# CRUD handler - Displays the UI for listing of existing pages.
sub show_config_pages {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};
    my $preferedLanguage = $cgi->cookie('KohaOpacLanguage');
    my $template = undef;
    eval {$template = $self->get_template( { file => "messaging_preference_wizard_$preferedLanguage.tt" } )};
    if(!$template){
        $preferedLanguage = substr $preferedLanguage, 0, 2;
        eval {$template = $self->get_template( { file => "messaging_preference_wizard_$preferedLanguage.tt" } )};
    }
    $template = $self->get_template( { file => 'messaging_preference_wizard.tt' } ) unless $template;
    $template->param( fin => 0);
    print $cgi->header();
    print $template->output();
}

# Generic uninstall routine - removes the plugin from plugin pages listing
sub uninstall() {
    my ( $self, $args ) = @_;
}
1;
