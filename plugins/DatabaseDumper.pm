# Rémi Mayrand-Provencher, 2016 - Inlibro
#
# Allows to dump the database and then download the said dump
# You need to add the <publicdumpdir>/path/to/dump/directory</publicdumpdir> directive to your koha-conf.xml
# The dump directory also needs to belong to www-data:www-data for the plugin to be able to write the dump inside it.
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
package Koha::Plugin::DatabaseDumper;

use Modern::Perl;

## Required for all plugins
use base qw(Koha::Plugins::Base);

## Koha libraries we need to access
use C4::Context;
use C4::Auth;

use CGI;
use C4::Output;
use C4::Koha;
use File::stat qw(stat);
use Digest::MD5 qw(md5_hex);


## Here we set our plugin version
our $VERSION = 1.01;

## Here is our metadata, some keys are required, some are optional
our $metadata = {
    name            => 'Database Dumper',
    author          => 'Rémi MP',
    description     => 'Allows database dumping directly from the intranet. Then gives a link to download the said dump',
    date_authored   => '2016-04-22',
    date_updated    => '2016-04-25',
    minimum_version => '3.1400000',
    maximum_version => undef,
    version         => $VERSION,
};

## This is the minimum code required for a plugin's 'new' method
## More can be added, but none should be removed
sub new {
    my ( $class, $args ) = @_;

    ## We need to add our metadata here so our base class can access it
    $args->{'metadata'} = $metadata;

    ## Here, we call the 'new' method for our base class
    ## This runs some additional magic and checking
    ## and returns our actual $self
    my $self = $class->SUPER::new($args);

    return $self;
}

sub tool {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $action = $cgi->param('action');

    if($action eq 'dump'){
        $self->dumpDatabase();
    }
    $self->databaseDumper();
}


sub databaseDumper {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $publicdumpdir = C4::Context->config('publicdumpdir');
    my $db_user = C4::Context->config('user');
    my $db_pass = C4::Context->config('pass');
    my $db_name = C4::Context->config('database');
    my @directories = $publicdumpdir ? (ref $publicdumpdir ? @{$publicdumpdir} : ($publicdumpdir)) : ();
    my $input = new CGI;
    my $file_id = $input->param("id");
    #`mysqldump -u $db_user -p$db_pass $db_name> $publicdumpdir/test.sql`;

    my $template = $self->get_template( { file => 'DatabaseDumper.tt' } );
    unless(@directories) {
        $template->param(error_no_dir => 1);
    }else{
        #Get the files list
        my @files_list;
        foreach my $dir(@directories){
            opendir(DIR, $dir);
            foreach my $filename (readdir(DIR)) {
            my $id = md5_hex($filename);
                my $full_path = "$dir/$filename";
                next if ($filename =~ /^\./ or -d $full_path);

                my $st = stat($full_path);
                my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =localtime($st->mtime);
                my $dt=DateTime->new(year      => $year + 1900,
                                      month    => $mon + 1,
                                      day      => $mday,
                                      hour     => $hour,
                                      minute   => $min,
                                );
                push(@files_list, {name => $filename,
                                   accessdir => $dir,
                                   date =>Koha::DateUtils::output_pref($dt),
                                   size => $st->size,
                                   id   => $id});
            }
            closedir(DIR);
        }

        my %files_hash = map { $_->{id} => $_ } @files_list;
        # If we received a file_id and it is valid, send the file to the browser
        if(defined $file_id and exists $files_hash{$file_id} ){
            my $filename = $files_hash{$file_id}->{name};
            my $dir = $files_hash{$file_id}->{accessdir};
            binmode STDOUT;
            # Open the selected file and send it to the browser
            print $input->header(-type => 'application/x-download',
                                 -name => "$filename",
                                 -Content_length => -s "$dir/$filename",
                                 -attachment => "$filename");

            my $fh;
            open $fh, "<:encoding(UTF-8)", "$dir/$filename";
            binmode $fh;

            my $buf;
            while(read($fh, $buf, 65536)) {
                print $buf;
            }
            close $fh;

            exit(1);
        }
        else{
            # Send the file list to the template
            $template->param(files_loop => \@files_list);
        }
    }
    print $cgi->header();
    print $template->output();
}

sub dumpDatabase {
	my $input = new CGI;
	my $publicdumpdir = C4::Context->config('publicdumpdir');
    my $db_user = C4::Context->config('user');
    my $db_pass = C4::Context->config('pass');
    my $db_name = C4::Context->config('database');
	my $dumpName = $input->param("dumpName");
	if(!$dumpName){
		$dumpName="dump";
	}
    `mysqldump -u $db_user -p$db_pass $db_name | gzip > $publicdumpdir/$dumpName.sql.gz`;
}

1;
