#!/usr/bin/perl

# Copyright 2025 Sam McLeod - Based on original AwesomeSlides converter by Z. Cliffe Schreuders https://github.com/cliffe/AwesomeSlides
# This version extracts style information and creates a custom RevealJS theme
#
# Licensed under the GNU Affero General Public License v3
# and Creative Commons Attribution-ShareAlike v4.0 International License

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

  my $output_slides_src = "./slides_template";
  my $output_slides_dest = "./slides_out";
  my $theme_dir = "$output_slides_dest/css/theme";

  my $filename_title = $file;
  $filename_title =~ s/\..*//ig;
  $filename_title =~ s/.*Modules \d\d\d\d\///ig;
  $filename_title =~ s/[^A-Za-z0-9-_]/_/ig;
  my $uri_filename_title = uri_encode($filename_title);

  # Create theme directory if it doesn't exist
  unless(-d $theme_dir) {
    make_path($theme_dir) or die "Could not create $theme_dir: $!";
  }

  my $input_slides = "./tmp/$$-$file";
  mkdir $input_slides;

  # Extract file
  my $ae = Archive::Extract->new( archive => $file, type => "zip" );
  $ae->extract( to => $input_slides ) or die $ae->error;

  # Process content.xml for slide content
  my ($slides_title, $title_sanitised, $uri_slides_title) = "";
  my $sections = "";
  my $parser = XML::LibXML->new();
  my $doc = $parser->parse_file("$input_slides/content.xml");

  # Process styles.xml for theme information
  my $styles_doc;
  if (-e "$input_slides/styles.xml") {
    $styles_doc = $parser->parse_file("$input_slides/styles.xml");
  } else {
    print "Warning: No styles.xml found, using default theme\n";
  }

  # Extract style information and create RevealJS theme
  my $theme_css = extract_theme_info($styles_doc, $doc);
  my $theme_name = lc($filename_title);

  # Write theme CSS file
  my $theme_file = "$theme_dir/$theme_name.css";
  open(my $theme_fh, '>', $theme_file) or die "Could not open file '$theme_file' $!";
  print $theme_fh $theme_css;
  close $theme_fh;
  print "Created theme: $theme_file\n";

  # Process slides content as in original script
  my $pagenumber = 0;

  # For each page
  foreach my $page ($doc->findnodes('//draw:page')) {
    $pagenumber++;
    my $title = "";
    my $outline = ""; # Explicitly initialize both variables
    my ($background_image, $slide_license, @images);
    my @attribution_image_license;
    my @attribution_text;
    my $extra_text = "";

    # For each frame element on the page
    foreach my $element ($page->findnodes('./draw:frame')) {
      # Get the type of element it is (title, etc)
      my $attribute = $element->getAttribute('presentation:class');

      if($attribute && $attribute eq "title") {
        my $title_node = $element->findnodes("./draw:text-box");
        if ($title_node && $title_node->size() > 0) {
          $title = $title_node->to_literal;
          if(!$slides_title) {
            $slides_title = $title;
          }
        }
      } elsif($attribute && $attribute eq "outline") {
        my $text = $element->findnodes("./draw:text-box");
        if ($text && $text->size() > 0) {
          my $xml_node = $text->get_node(1);
          $outline = build_outline($xml_node->toString, "embed");
        } else {
          $outline = ""; # Default to empty if no outline content
        }
      } else {
        my $img = $element->findnodes("./draw:image");
        if($img && $img->size() > 0) {
          my $xml_node = $img->get_node(1);
          my $img_height = $element->getAttribute('svg:height');
          my $img_width = $element->getAttribute('svg:width');
          my $img_src = $xml_node->getAttribute('xlink:href');
          $img_src =~ s|^Pictures/||ig;

          # Convert dimensions
          $img_height =~ s/[^0-9.]//ig;
          $img_height = sprintf("%.1f", $img_height);
          $img_width =~ s/[^0-9.]//ig;
          $img_width = sprintf("%.1f", $img_width);

          if($img_height > 13 && ($img_width > 18 || $pagenumber == 1)) {
            # Image to use as a background image
            if(!$background_image) {
              $background_image = $img_src;
            } else {
              # Image to include on slide
              unshift (@images, $img_src);
            }
          } else {
            # Handle smaller images
            unshift (@images, $img_src);
          }
        } else {
          # Handle additional text
          my $text = $element->findnodes("./draw:text-box");
          if($text && $text->size() > 0) {
            my $xml_node = $text->get_node(1);
            my $more = build_outline($xml_node->toString, "don't embed");
            $extra_text .= $more;
          }
        }
      }
    }

    # Create slide content
    # Include extra text that was previously skipped
    if ($extra_text) {
      $outline .= "\n\t\t<div class=\"extra-content\">\n\t\t\t$extra_text\n\t\t</div>";
    }

    # Slide creation logic
    my $background_html = ""; # Initialize with empty string
    my ($attribution_html, $slide_license_html);
    if($background_image) {
      $background_html = " data-background='images/$uri_filename_title/$background_image'";
    }
    my $images_html = "";
    foreach my $item (@images) {
      $images_html .= "\t\t<img src='images/$uri_filename_title/$item'>\n";
    }

    my $headingtag = "h2";
    if($pagenumber == 1) {
      $headingtag = "h1";
    }

    $sections .= <<SECTION;
\t<section$background_html>
\t\t<$headingtag>$title</$headingtag>
$images_html
\t\t$outline
\t</section>
SECTION
  }

  # Create the HTML output using the custom theme
  my $output = <<HTML;
<!doctype html>
<html lang="en">

<head>
\t<meta charset="utf-8">
\t<title>$slides_title</title>
\t<meta name="generator" content="ODP to RevealJS Converter" />
\t<meta name="apple-mobile-web-app-capable" content="yes" />
\t<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent" />
\t<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, minimal-ui">
\t<base target="_blank">
\t<link rel="stylesheet" href="css/reveal.css">
\t<link rel="stylesheet" href="css/theme/$theme_name.css" id="theme">
\t<link rel="stylesheet" href="lib/css/zenburn.css">
\t<script>
\t\tif( window.location.search.match( /print-pdf/gi ) ) {
\t\t\tvar link = document.createElement( 'link' );
\t\t\tlink.rel = 'stylesheet';
\t\t\tlink.type = 'text/css';
\t\t\tlink.href = 'css/print/pdf.css';
\t\t\tdocument.getElementsByTagName( 'head' )[0].appendChild( link );
\t\t}
\t</script>
\t<!--[if lt IE 9]>
\t<script src="lib/js/html5shiv.js"></script>
\t<![endif]-->
</head>

<body>
\t<div class="reveal">
\t\t<div class="slides">
$sections
\t\t</div>
\t</div>

\t<script src="lib/js/head.min.js"></script>
\t<script src="js/reveal.js"></script>
\t<script>
\t\tReveal.initialize({
\t\t\tcontrols: true,
\t\t\tprogress: true,
\t\t\thistory: true,
\t\t\tcenter: true,
\t\t\ttransition: 'slide', // none/fade/slide/convex/concave/zoom
\t\t\tdependencies: [
\t\t\t\t{ src: 'lib/js/classList.js', condition: function() { return !document.body.classList; } },
\t\t\t\t{ src: 'plugin/markdown/marked.js', condition: function() { return !!document.querySelector( '[data-markdown]' ); } },
\t\t\t\t{ src: 'plugin/markdown/markdown.js', condition: function() { return !!document.querySelector( '[data-markdown]' ); } },
\t\t\t\t{ src: 'plugin/highlight/highlight.js', async: true, condition: function() { return !!document.querySelector( 'pre code' ); }, callback: function() { hljs.initHighlightingOnLoad(); } },
\t\t\t\t{ src: 'plugin/zoom-js/zoom.js', async: true },
\t\t\t\t{ src: 'plugin/notes/notes.js', async: true }
\t\t\t]
\t\t});
\t</script>
</body>
</html>
HTML

  # Write the HTML to a file
  dircopy($output_slides_src, $output_slides_dest) or die "Could not copy framework files to $output_slides_dest: $!";

  my $filename = "$output_slides_dest/$filename_title.html";
  open(my $fh, '>', $filename) or die "Could not open file '$filename' $!";
  print $fh $output;
  close $fh;
  print "Done: Wrote to $filename\n";

  # Copy images
  my $images_dir = "$output_slides_dest/images/$filename_title";
  dircopy("$input_slides/Pictures", $images_dir) or die "Could not copy images to $images_dir: $!";
  print "Done: Copied images to: $images_dir\n";
}

sub extract_theme_info {
  my ($styles_doc, $content_doc) = @_;

  # Default theme values
  my $theme = {
    background_color => "#f7f2d3",
    text_color => "#333333",
    heading_color => "#222222",
    link_color => "#2a76dd",
    font_family => "'Source Sans Pro', Helvetica, sans-serif",
    heading_font => "'Source Sans Pro', Helvetica, sans-serif",
    heading_text_shadow => "none",
    heading_text_transform => "uppercase",
    heading_font_weight => "600",
    code_font => "monospace",
  };

  # Return default theme if no styles document provided
  return generate_css_from_theme($theme) unless $styles_doc;

  # Extract style information
  print "Extracting style information...\n";

  # Find presentation background color
  my $bg_styles = $styles_doc->findnodes('//style:style[@style:family="drawing-page"]');
  foreach my $style ($bg_styles->get_nodelist()) {
    my $bg_props = $style->findnodes('./style:drawing-page-properties');
    if ($bg_props && $bg_props->size() > 0) {
      my $bg_prop = $bg_props->get_node(1);
      my $bg_color = $bg_prop->getAttribute('draw:fill-color');
      $theme->{background_color} = $bg_color if $bg_color;

      my $fill = $bg_prop->getAttribute('draw:fill');
      # Add gradient support, etc. as needed
    }
  }

  # Find text styles
  my $text_styles = $styles_doc->findnodes('//style:style[@style:family="text"]');
  foreach my $style ($text_styles->get_nodelist()) {
    my $text_props = $style->findnodes('./style:text-properties');
    if ($text_props && $text_props->size() > 0) {
      my $text_prop = $text_props->get_node(1);
      my $font_family = $text_prop->getAttribute('style:font-name');
      my $font_size = $text_prop->getAttribute('fo:font-size');
      my $color = $text_prop->getAttribute('fo:color');

      # Store these values
      if ($style->getAttribute('style:name') =~ /title/i || $style->getAttribute('style:name') =~ /heading/i) {
        $theme->{heading_font} = $font_family if $font_family;
        $theme->{heading_color} = $color if $color;
      } else {
        $theme->{font_family} = $font_family if $font_family;
        $theme->{text_color} = $color if $color;
      }
    }
  }

  # Find paragraph styles
  my $para_styles = $styles_doc->findnodes('//style:style[@style:family="paragraph"]');
  foreach my $style ($para_styles->get_nodelist()) {
    my $para_props = $style->findnodes('./style:paragraph-properties');
    my $text_props = $style->findnodes('./style:text-properties');

    if ($text_props && $text_props->size() > 0 && $style->getAttribute('style:name') =~ /title/i) {
      my $text_prop = $text_props->get_node(1);
      my $font_weight = $text_prop->getAttribute('fo:font-weight');
      my $text_transform = $text_prop->getAttribute('fo:text-transform');

      $theme->{heading_font_weight} = $font_weight if $font_weight;
      $theme->{heading_text_transform} = $text_transform if $text_transform;
    }
  }

  # Generate CSS from the extracted theme information
  return generate_css_from_theme($theme);
}

sub generate_css_from_theme {
  my ($theme) = @_;

  # Create a RevealJS theme CSS file based on extracted information
  my $css = <<CSS;
/**
 * Custom theme generated from ODP file
 */

.reveal {
  font-family: $theme->{font_family};
  font-size: 40px;
  font-weight: normal;
  color: $theme->{text_color};
}

.reveal .slides section,
.reveal .slides section > section {
  line-height: 1.3;
  font-weight: inherit;
}

/* Headings */
.reveal h1,
.reveal h2,
.reveal h3,
.reveal h4,
.reveal h5,
.reveal h6 {
  margin: 0 0 20px 0;
  color: $theme->{heading_color};
  font-family: $theme->{heading_font};
  font-weight: $theme->{heading_font_weight};
  line-height: 1.2;
  letter-spacing: normal;
  text-transform: $theme->{heading_text_transform};
  text-shadow: $theme->{heading_text_shadow};
  word-wrap: break-word;
}

.reveal h1 {
  font-size: 3.77em;
}

.reveal h2 {
  font-size: 2.11em;
}

.reveal h3 {
  font-size: 1.55em;
}

.reveal h4 {
  font-size: 1em;
}

/* Links */
.reveal a {
  color: $theme->{link_color};
  text-decoration: none;
  transition: color .15s ease;
}

.reveal a:hover {
  color: #6ca0e8;
  text-shadow: none;
  border: none;
}

/* Background */
body {
  background: $theme->{background_color};
}

.reveal {
  background: $theme->{background_color};
}

/* Extra content (previously skipped) */
.extra-content {
  margin-top: 1em;
  font-size: 0.8em;
  color: #666;
  border-top: 1px solid #ccc;
  padding-top: 0.5em;
}

/* Other elements */
.reveal code {
  font-family: $theme->{code_font};
}

.reveal pre {
  display: block;
  position: relative;
  width: 90%;
  margin: 20px auto;
  text-align: left;
  font-size: 0.55em;
  font-family: $theme->{code_font};
  line-height: 1.2em;
  word-wrap: break-word;
  box-shadow: 0px 5px 15px rgba(0, 0, 0, 0.15);
}

.reveal table {
  margin: auto;
  border-collapse: collapse;
  border-spacing: 0;
}

.reveal table th {
  font-weight: bold;
}

.reveal table th,
.reveal table td {
  text-align: left;
  padding: 0.2em 0.5em;
  border-bottom: 1px solid;
}
CSS

  return $css;
}

# Include the existing build_outline function
sub build_outline {
  my ($xml, $embed) = @_;
  my $html = $xml;

  # encode non-ASCII characters
  $html =~ s/([^[\x20-\x7F])/"&#".ord($1).";"/eg;

  # remove things that we ignore
  $html =~ s/<\/?draw:text-box>|<\/?text:list-header>|text:style-name=".*?"|type="simple"//ig;
  # convert elements to html
  $html =~ s/text:list-item/li/ig;
  $html =~ s/text:list/ul/ig;
  $html =~ s/text:p/p/ig;
  $html =~ s/text:span/span/ig;
  $html =~ s/text:a/a/ig;
  $html =~ s/xlink://ig;
  $html =~ s/<text:line-break\/>/<br \/>/ig;

  # remove spaces before >
  $html =~ s/\s+>/>/ig;

  # remove <p> in lists
  $html =~ s/(<li>|<ul>)\s*<p>(\s*.*?\s*)<\/p>/$1$2/ig;

  # automatically convert a slide with a single link displayed to an iframe
  if($html !~ m#href="https?://www.youtube.com/watch#) {
      $html =~ s#^(?:\<ul>|</ul>|<span>|</span>|<p>|</p>|<li>|</li>|<br />)*<a href="(https?://[^<]+)">(https?://[^<]+)</a>(?:\<ul>|</ul>|<span>|</span>|<p>|</p>|<li>|</li>|<br />)*$#<iframe width="900" height="500" src="$1" frameborder="0" allowFullScreen></iframe><p class="iframe-caption"><a href="$1">$2</a></p>#ig if $embed eq "embed";
  }

  # keep multiple spaces
  $html =~ s/<text:s text:c="(\d+)"\/>/'&nbsp;' x $1/ige;

  # remove <text:tab/> etc
  $html =~ s/<\/?text:[a-zA-Z0-9_]*\/?>//ig;

  # newline when starting a list
  $html =~ s/<ul>/\n<ul>\n/ig;
  # new lines between points
  $html =~ s/<\/li>/<\/li>\n/ig;
  # add spaces before points
  $html =~ s/<li>/<li>/ig;

  # remove spans with no attributes
  $html =~ s/<span>(.*?)<\/span>/$1/ig;
  $html =~ s/<span \/>//ig;
  $html =~ s/<p><\/p>//ig;
  # remove blank bullet points
  $html =~ s/<li>(?:<p \/>)+<\/li>//ig;

  # remove empty a (no text)
  $html =~ s/<a href="[^"]*?"><\/a>//ig;
  $html =~ s/<a href="[^"]*?"\s?\/>//ig;

  return $html;
}
