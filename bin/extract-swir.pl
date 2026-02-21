use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->child ('modules/*/lib');
use SWML::Parser;
use Web::DOM::Document;
use Web::DomainName::Punycode;
use JSON::PS;

my $NO_GIT = $ENV{NO_GIT};

my $RootPath = path (__FILE__)->parent->parent;
my $SWDataPath = $RootPath->child ('local/data');
my $OutPath = $RootPath->child ('data/extracted');

my $IDList = {};
{
  my $path = $RootPath->child ('local/swir-files.txt');
  for (split /\n/, $path->slurp) {
    if (m{^(ids/([0-9]+)/([0-9]+))\.props$}) {
      $IDList->{$2 * 1000 + $3} = 1;
    }
  }
}

system "cd \Q$RootPath\E && git rm -r \Q@{[$OutPath->relative ($RootPath)]}\E"
    unless $NO_GIT;
$OutPath->mkpath;
{
  my $name = "swir-ids.txt";
  my $path = $OutPath->child ($name);
  $path->spew (join "\x0A", sort { $a <=> $b } keys %$IDList);
  system "cd \Q$RootPath\E && git add \Q@{[$path->relative ($RootPath)]}\E"
      unless $NO_GIT;
}

print STDERR "\rDone \n";

## License: Public Domain.
