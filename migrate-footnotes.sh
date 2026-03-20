#!/usr/bin/env bash
set -euo pipefail

PATH_ARG="."
INCLUDE_BACKUPS=0
KEEP_BACKUP=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --path)
      PATH_ARG="${2:-}"
      shift 2
      ;;
    --include-backups)
      INCLUDE_BACKUPS=1
      shift
      ;;
    --nobackup)
      KEEP_BACKUP=0
      shift
      ;;
    --write-backup)
      # Backward-compatible alias for the old option behavior.
      KEEP_BACKUP=1
      shift
      ;;
    -h|--help)
      cat <<'EOF'
Usage: ./migrate-footnotes.sh [--path DIR] [--include-backups] [--nobackup]

Migrates HTML files to canonical footnote markup for main.js.

Options:
  --path DIR          Directory containing html files (default: .)
  --include-backups   Include files ending in .backup.html or -backup.html
  --nobackup          Do not create per-file -backup.html copy (default creates)
EOF
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

shopt -s nullglob
files=("$PATH_ARG"/*.html)

if [[ ${#files[@]} -eq 0 ]]; then
  echo "No .html files found in $PATH_ARG"
  exit 0
fi

for file in "${files[@]}"; do
  name="$(basename "$file")"
  if [[ $INCLUDE_BACKUPS -eq 0 && ( "$name" == *.backup.html || "$name" == *-backup.html ) ]]; then
    continue
  fi

  if [[ $KEEP_BACKUP -eq 1 ]]; then
    backup_file="${file%.html}-backup.html"
    cp -f -- "$file" "$backup_file"
  fi

  perl - "$file" <<'PERL'
use strict;
use warnings;

my $file = shift @ARGV;
local $/;
open my $fh, '<', $file or die "Cannot read $file: $!";
my $content = <$fh>;
close $fh;

sub get_attr {
  my ($attrs, $name) = @_;
  return $1 if $attrs =~ /\b\Q$name\E="([^"]*)"/i;
  return undef;
}

sub set_attr {
  my ($attrs, $name, $value) = @_;
  if ($attrs =~ /\b\Q$name\E="[^"]*"/i) {
    $attrs =~ s/\b\Q$name\E="[^"]*"/$name="$value"/ig;
    return $attrs;
  }
  $attrs =~ s/\s+$//;
  return "$attrs $name=\"$value\"";
}

sub remove_attr {
  my ($attrs, $name) = @_;
  $attrs =~ s/\s+\b\Q$name\E="[^"]*"//ig;
  return $attrs;
}

sub ensure_fn_class {
  my ($attrs) = @_;
  my $class = get_attr($attrs, 'class');
  if (!defined $class) {
    $attrs =~ s/\s+$//;
    return "$attrs class=\"fn\"";
  }

  my @parts = grep { length $_ } split /\s+/, $class;
  my %seen;
  @parts = grep { !$seen{$_}++ } @parts;
  push @parts, 'fn' unless grep { $_ eq 'fn' } @parts;
  my $new_class = join ' ', @parts;
  return set_attr($attrs, 'class', $new_class);
}

# Ensure canonical note container.
$content =~ s/<section>\s*(?=<p\s+id="fn)/<section class="ref">/ig;

# Normalize note IDs from ref* to fn* if needed.
$content =~ s/<p([^>]*?)\sid="ref([^"]+)"/<p$1 id="fn$2"/ig;

# Remove static note backlinks and old leading counters.
$content =~ s/\s*<a\s+href="#ref[^"]*"\s*>\s*↩\s*<\/a>//ig;
$content =~ s{(<p[^>]*\sid="fn[^"]+"[^>]*>\s*)(?:\[?\d+\]?(?:[:.])\s*)}{$1}ig;

# Remove manual sup wrapper around fn citations.
$content =~ s{<sup>\s*(<a[^>]*\bclass="[^"]*\bfn\b[^"]*"[^>]*>.*?</a>)\s*</sup>}{$1}sig;

# Canonicalize fn citation anchors.
$content =~ s{<a([^>]*)>(.*?)</a>} {
  my ($attrs, $inner) = ($1, $2);
  my $out = "<a$attrs>$inner</a>";

  my $class = get_attr($attrs, 'class');
  my $id = get_attr($attrs, 'id');
  my $href = get_attr($attrs, 'href');
  my $data_fn = get_attr($attrs, 'data-fn');

  my $is_fn_class = 0;
  if (defined $class) {
    my @parts = split /\s+/, $class;
    $is_fn_class = scalar grep { $_ eq 'fn' } @parts;
  }

  my $is_old_ref = defined($id) && $id =~ /^ref/ && defined($href) && $href =~ /^#fn/;
  if ($is_fn_class || $is_old_ref) {
    my $key;
    if (defined $data_fn && $data_fn ne '') {
      $key = $data_fn;
    } elsif (defined $id && $id =~ /^ref(.+)$/) {
      $key = $1;
    } elsif (defined $id && $id =~ /^fn(.+)$/) {
      $key = $1;
    } elsif (defined $href && $href =~ /^#fn(.+)$/) {
      $key = $1;
    }

    if (defined $key && $key ne '') {
      $attrs = ensure_fn_class($attrs);
      $attrs = remove_attr($attrs, 'href');
      $attrs = set_attr($attrs, 'id', "ref$key");

      $out = "<a$attrs>*</a>";
    }
  }

  $out;
}esig;

# For duplicate citations to same key, convert later ones to data-fn.
my %seen_key;
$content =~ s{<a([^>]*\bclass="[^"]*\bfn\b[^"]*")>\*</a>} {
  my $attrs = $1;
  my $out = "<a$attrs>*</a>";
  my $id = get_attr($attrs, 'id');
  my $data_fn = get_attr($attrs, 'data-fn');

  my $key;
  if (defined $data_fn && $data_fn ne '') {
    $key = $data_fn;
  } elsif (defined $id && $id =~ /^ref(.+)$/) {
    $key = $1;
  }

  if (defined $key && $key ne '') {
    if ($seen_key{$key}) {
      $attrs = remove_attr($attrs, 'id');
      $attrs = set_attr($attrs, 'data-fn', $key);
    } else {
      $seen_key{$key} = 1;
    }

    $out = "<a$attrs>*</a>";
  }

  $out;
}esig;

open my $out, '>', $file or die "Cannot write $file: $!";
print {$out} $content;
close $out;
PERL

  echo "Migrated $name"
done
