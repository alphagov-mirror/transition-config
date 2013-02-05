#!/usr/bin/env perl

#
#  validate CSV file format
#
use Test::More;

my $file = shift;
my $domain = shift // "";
my $whitelist = shift // "data/whitelist.csv";
my $test = ValidateCSV->new($file, $domain);

$test->load_whitelist($whitelist);
$test->run_tests();

done_testing();
exit;

package ValidateCSV;

use v5.10;
use strict;
use warnings;

use Test::More;
use Text::CSV;
use HTTP::Request;
use LWP::UserAgent;
use URI;

sub new {
    my $class = shift;
    my $file  = shift;
    my $domain  = shift;

    my $self = {
            input_file => $file,
            domain => $domain,
        };

    bless $self, $class;
    return $self;
}

sub run_tests {
    my $self = shift;

    my $csv = Text::CSV->new({ binary => 1 })
                or die "Cannot use CSV: " . Text::CSV->error_diag();

    open( my $fh, "<", $self->{'input_file'} )
            or die "$self->{'input_file'}: $!";

    my $names = $csv->getline( $fh );
    $csv->column_names( @$names );

    while ( my $row = $csv->getline_hr( $fh ) ) {
        $self->test($row);
    }
}

sub check_url {
    my ($self, $name, $url) = @_;

    $url =~ s/\|/%7C/g;

    ok($url =~ m{^https?://}, "$name '$url' should be a full URI line $.");

    ok($url !~ m{,}, "bare comma in $name $url line $.");

    my $uri = URI->new($url);
    is($uri, $url, "$name '$url' should be a valid URI line $.");

    return $uri;
}

sub test_source_line {
    my $self = shift;
    my $row  = shift;
    my $domain = $self->{domain};

    my $old_url = $row->{'Old Url'} // '';
    my $new_url = $row->{'New Url'} // '';
    my $status = $row->{'Status'} // '';

    $self->check_url('Old Url', $old_url);

    ok($old_url =~ m{^https?://$domain}, "old url [$old_url] domain not [$domain] line $.");

    if ( "301" eq $status) {
        my $uri = $self->check_url('New Url', $new_url);
        ok($self->{whitelist}->{$uri->host}, "host " . $uri->host . " not in whitelist line $.");
    } elsif ( "410" eq $status) {
        ok($new_url eq '', "unexpected New Url for 410: [$new_url] line $.");
    } elsif ( "200" eq $status) {
        ok($new_url eq '', "unexpected New Url for 200: [$new_url] line $.");
    } else {
       fail("unexpected Status code: [$status] line $.");
    }
}

sub test {
    my $self = shift;
    $self->test_source_line(@_);
}

sub load_whitelist {
    my $self = shift;
    my $filename = shift;
    local *FILE;
    open(FILE, "< $filename") or die "unable to open whitelist $filename";
    while (<FILE>) {
        chomp;
        $self->{whitelist}->{$_} = 1;
    }
}
