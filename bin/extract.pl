use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->child ('modules/*/lib');
use SWML::Parser;
use Web::DOM::Document;
use Web::DomainName::Punycode;
use JSON::PS;

my $RootPath = path (__FILE__)->parent->parent;
my $SWDataPath = $RootPath->child ('local/data');
my $OutPath = $RootPath->child ('data/extracted');

my $FileList = {};
{
  my $path = $RootPath->child ('local/files.txt');
  for (split /\n/, $path->slurp) {
    if (m{^(ids/[0-9]+/[0-9]+\.txt):}) {
      $FileList->{$1} = 1;
    }
  }
}

my $AllData = {};

sub to_text ($) {
  my $el = shift;

  my $e;
  my $has_text = 0;
  my $text = '';
  for (@{$el->child_nodes}) {
    if ($_->node_type == $_->ELEMENT_NODE) {
      if ({
        'anchor' => 1,
        'dfn' => 1,
      }->{$_->local_name}) {
        $has_text = 1 if defined $e;
        $e = $_;
        $text .= $_->text_content;
      } elsif ($_->local_name eq 'anchor-end') {
        #
      } else {
        $has_text = 1;
        $text .= $_->text_content;
      }
    } elsif ($_->node_type == $_->TEXT_NODE) {
      my $d = $_->text_content;
      $has_text ||= ($d =~ /\S/);
      $text .= $d;
    }
  }

  if (defined $e and not $has_text) {
    my $title;
    my $tc = '';
    for (@{$e->child_nodes}) {
      if ($_->node_type == $_->ELEMENT_NODE) {
        if ($_->local_name eq 'title') {
          $title = $_->text_content;
          last;
        } else {
          $tc .= $_->text_content;
        }
      } elsif ($_->node_type == $_->TEXT_NODE) {
        $tc .= $_->text_content;
      }
    }
    $text = defined $title ? $title : $tc;
  }
  $text =~ s/\s+/ /g;
  $text =~ s/^ //;
  $text =~ s/ $//;
  return $text;
} # to_text

for my $file_name (sort { $a cmp $b } keys %$FileList) {
  print STDERR "\r$file_name ...";
  my $path = $SWDataPath->child ($file_name);
  my $parser = SWML::Parser->new;
  $parser->onerror (sub { });
  my $doc = new Web::DOM::Document;
  $parser->parse_char_string ($path->slurp_utf8 => $doc);

  for my $data_el (@{$doc->query_selector_all ('figure.data')}) {
    my $type = '';
    my $props = {};
    for my $el (@{$data_el->children}) {
      if ($el->local_name eq 'dl') {
        my $label;
        for (@{$el->children}) {
          if ($_->local_name eq 'dt') {
            $label = to_text $_;
          } elsif ($_->local_name eq 'dd') {
            my $v = {};
            $v->{text} = to_text $_;
            $v->{xml} = $_->inner_html;
            push @{$props->{$label} ||= []}, $v;
          }
        }
      } elsif ($el->local_name eq 'figcaption') {
        $type = to_text $el;
      }
    }
    
    $type = substr $type, 0, 63;
    push @{$AllData->{$type} ||= []}, $props;
  }
}

system "cd \Q$RootPath\E && git rm -r \Q@{[$OutPath->relative ($RootPath)]}\E";
$OutPath->mkpath;
for my $type (sort { $a cmp $b } keys %$AllData) {
  my $name = encode_punycode $type;
  $name =~ s/([^0-9A-Za-z-])/sprintf '_%02X', ord $1/ge;
  $name = "data-$name.json";
  my $path = $OutPath->child ($name);

  $path->spew (perl2json_bytes_for_record $AllData->{$type});
  system "cd \Q$RootPath\E && git add \Q@{[$path->relative ($RootPath)]}\E";
}

print STDERR "\rDone \n";

## License: Public Domain.
