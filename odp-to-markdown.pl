#!/usr/bin/perl

# Copyright 2025 Sam McLeod - Based on original AwesomeSlides converter by Z. Cliffe Schreuders
# This version creates Markdown output instead of HTML/RevealJS
#
# Licensed under the GNU Affero General Public License v3
# and Creative Commons Attribution-ShareAlike v4.0 International License
#
# You man need to run cpan install XML::LibXML Archive::Extract File::Copy::Recursive Term::ANSIColor

use strict;
use warnings;
use Data::Dumper qw(Dumper);
use File::Copy::Recursive qw(dircopy);
use URI::Encode qw(uri_encode uri_decode);
use Archive::Extract;
use XML::LibXML;
use utf8;
use Term::ANSIColor;
use File::Path qw(make_path);

my $numArgs = $#ARGV + 1;
if($numArgs == 0) {
  die "Please provide odp file(s) on the command line\n";
}

foreach my $file (@ARGV) {
  process_file($file);
}

sub process_file {
  my ($file) = @_;

  print "Processing $file\n";

  my $output_dir = "./markdown_out";
  my $images_dir = "$output_dir/images";

  # Create output directories if they don't exist
  unless(-d $output_dir) {
    mkdir $output_dir or die "Could not create $output_dir: $!";
  }

  unless(-d $images_dir) {
    mkdir $images_dir or die "Could not create $images_dir: $!";
  }

  my $filename_title = $file;
  $filename_title =~ s/\..*//ig;
  $filename_title =~ s/.*Modules \d\d\d\d\///ig;
  $filename_title =~ s/[^A-Za-z0-9-_]/_/ig;

  # Create a directory for this file's images
  my $file_images_dir = "$images_dir/$filename_title";
  unless(-d $file_images_dir) {
    mkdir $file_images_dir or die "Could not create $file_images_dir: $!";
  }

  my $input_slides = "./tmp/$$-$file";
  unless(-d "./tmp") {
    mkdir "./tmp" or die "Could not create ./tmp: $!";
  }

  unless(-d $input_slides) {
    mkdir $input_slides or die "Could not create $input_slides: $!";
  }

  # Extract file
  my $ae = Archive::Extract->new( archive => $file, type => "zip" );
  $ae->extract( to => $input_slides ) or die $ae->error;

  my $slides_title = "";
  my $markdown_content = "";
  my $parser = XML::LibXML->new();
  my $doc = $parser->parse_file("$input_slides/content.xml");
  my $pagenumber = 0;

  # Add a header with metadata
  $markdown_content .= "---\n";
  $markdown_content .= "title: \"" . ($slides_title || $filename_title) . "\"\n";
  $markdown_content .= "date: " . localtime() . "\n";
  $markdown_content .= "output: markdown_document\n";
  $markdown_content .= "---\n\n";

  # For each page (slide)
  foreach my $page ($doc->findnodes('//draw:page')) {
    $pagenumber++;
    my ($title, $outline) = "";
    my @images;
    my $extra_text = "";
    my $background_image;

    # Add a separator between slides
    if ($pagenumber > 1) {
      $markdown_content .= "\n---\n\n";
    }

    # For each element on the page
    foreach my $element ($page->findnodes('./draw:frame')) {
      # Get the type of element
      my $attribute = $element->getAttribute('presentation:class');

      if($attribute && $attribute eq "title") {
        my $title_node = $element->findnodes("./draw:text-box");
        if ($title_node) {
          $title = $title_node->to_literal;
          if(!$slides_title) {
            $slides_title = $title;
          }
        }
      } elsif($attribute && $attribute eq "outline") {
        my $text = $element->findnodes("./draw:text-box");
        my @xml = $text->get_nodelist();
        if (@xml && defined $xml[0]) {
          $outline = build_markdown_outline($xml[0]->toString);
        }
      } else {
        # Handle images
        my $img = $element->findnodes("./draw:image");
        if($img && $img->size() > 0) {
          my @xml = $img->get_nodelist();
          if(@xml && defined $xml[0]) {
            my $img_src = $xml[0]->getAttribute('xlink:href');
            $img_src =~ s|^Pictures/||ig;

            # Handle image dimensions
            my $img_height = $element->getAttribute('svg:height');
            my $img_width = $element->getAttribute('svg:width');

            # Convert dimensions to number format
            $img_height =~ s/[^0-9.]//ig;
            $img_height = sprintf("%.1f", $img_height);
            $img_width =~ s/[^0-9.]//ig;
            $img_width = sprintf("%.1f", $img_width);

            # If it's a large image, consider it a main image
            if($img_height > 10 && $img_width > 10) {
              if(!$background_image) {
                $background_image = $img_src;
              } else {
                push(@images, $img_src);
              }
            } else {
              # Smaller image, add to regular images
              push(@images, $img_src);
            }
          }
        } else {
          # Handle text that's not in the outline or title
          my $text = $element->findnodes("./draw:text-box");
          if($text && $text->size() > 0) {
            my @xml = $text->get_nodelist();
            if(@xml && defined $xml[0]) {
              my $more = build_markdown_outline($xml[0]->toString);
              $extra_text .= $more if $more;
            }
          }
        }
      }
    }

    # Now create the Markdown content for this slide

    # Add title as a header
    if ($title) {
      # Use H1 for the first slide, H2 for all others
      my $header_level = ($pagenumber == 1) ? "#" : "##";
      $markdown_content .= "$header_level $title\n\n";
    }

    # Add background image if present
    if ($background_image) {
      $markdown_content .= "![Background Image](images/$filename_title/$background_image)\n\n";
    }

    # Add other images
    foreach my $image (@images) {
      $markdown_content .= "![](images/$filename_title/$image)\n\n";
    }

    # Add outline content
    if ($outline) {
      $markdown_content .= "$outline\n\n";
    }

    # Add extra text (previously skipped) if present
    if ($extra_text) {
      $markdown_content .= "**Additional Content:**\n\n$extra_text\n\n";
    }
  }

  # Write the markdown to a file
  my $output_file = "$output_dir/$filename_title.md";
  open(my $fh, '>', $output_file) or die "Could not open file '$output_file' $!";
  print $fh $markdown_content;
  close $fh;
  print "Done: Wrote markdown to $output_file\n";

  # Copy images
  dircopy("$input_slides/Pictures", $file_images_dir) or die "Could not copy images to $file_images_dir: $!";
  print "Done: Copied images to: $file_images_dir\n";
}

sub build_markdown_outline {
  my ($xml) = @_;
  my $markdown = $xml;

  # Remove things we ignore
  $markdown =~ s/<\/?draw:text-box>|<\/?text:list-header>|text:style-name=".*?"|type="simple"//ig;

  # Convert lists
  $markdown =~ s/<text:list-item>/\n* /ig;
  $markdown =~ s/<\/text:list-item>//ig;
  $markdown =~ s/<text:list>//ig;
  $markdown =~ s/<\/text:list>//ig;

  # Convert paragraphs
  $markdown =~ s/<text:p>/\n/ig;
  $markdown =~ s/<\/text:p>/\n/ig;

  # Convert spans
  $markdown =~ s/<text:span>//ig;
  $markdown =~ s/<\/text:span>//ig;

  # Convert links
  $markdown =~ s/<text:a href="([^"]*)">(.*?)<\/text:a>/[$2]($1)/ig;

  # Convert line breaks
  $markdown =~ s/<text:line-break\/>/\n/ig;

  # Handle spaces
  $markdown =~ s/<text:s text:c="(\d+)">/' ' x $1/ige;

  # Remove other XML tags
  $markdown =~ s/<\/?[a-zA-Z0-9_:]*\/?>//g;

  # Clean up excess whitespace
  $markdown =~ s/^\s+//;
  $markdown =~ s/\s+$//;
  $markdown =~ s/\n{3,}/\n\n/g;

  return $markdown;
}
