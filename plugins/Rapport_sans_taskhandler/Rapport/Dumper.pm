# Copyright 2016 Solutions inLibro
#
# À utiliser en ajouter une ligne genre     Koha::Plugin::Rapport::Dumper->new()->dump('isTargetAudience', $record->subfield(999, 'c'); dans le code
#
use Modern::Perl;
package Koha::Plugin::Rapport::Dumper;


my $singleton = undef;

sub new{
    my ($class) = @_;
    
    return $singleton if defined $singleton;
    
    my $self = {};
    $singleton = bless ($self, $class);
    return $singleton;
}

sub dump{
    my ($self,$nom, $val) = @_;
    
    if(! $self->{$nom . '_fh'}){
        my $filename = "/tmp/rapport_debug_$nom";
        open my $fh, ">$filename" or die "Can't open '$filename':$!";
        $self->{$nom . '_fh'} = $fh;
    }
    print {$self->{$nom . '_fh'}} "$val\n";
}

1;