package IMDB::Movie;

use strict;
use vars qw($VERSION $AUTOLOAD);

use Carp;
use LWP::Simple;
use HTML::TokeParser;

$VERSION = '0.01';
use constant URL => 'http://us.imdb.com/Title';

sub new {
	my ($class,$id) = @_;
	carp "can't instantiate $class without id or keyword" unless $id;
	$id = sprintf("%07d",$id) unless length($id) == 8;
	warn "fetching $id\n";

	my $parser = _get_toker($id);
	my ($title,$year);

	# get the ball rolling here
	($parser,$title,$year) = _title_year($parser,$id);

	$title =~ tr/"//d;

	# need better way to handle errors, maybe?
	carp "$id turned up no matches" unless $parser;

	my $self = {
		title    => $title,
		year     => $year,
		id       => _id($parser),
		img      => _image($parser),
		director => _director($parser),
		writer   => _director($parser),
		genre    => _genre($parser),
	};
	return bless $self, $class;
}

sub to_string() {
	my $self = shift;
	return sprintf("%s (%s) by %s", 
		$self->{title},
		$self->{year},
		join(', ',@{$self->{director}}),
	);

}

sub AUTOLOAD {
	my ($self) = @_;
	$AUTOLOAD =~ /.*::(\w+)/ && exists $self->{$1} and return $self->{$1};
	croak "No such attribute: $1";
}

sub DESTROY {}

############################################################################

sub _title_year {
	my $parser = shift;
	my $id     = shift;
	my ($title,$year);

	$parser->get_tag('title');
	$title = $parser->get_text();

	if ($title eq 'IMDb title search') {
		$id = _get_lucky($parser,$id);

		# start over
		$parser = _get_toker($id);
		$parser->get_tag('title');
		$title = $parser->get_text();
	}

	return ($parser,$1,$2) if $title =~ /([^\(]+)\s+\((\d{4})/;

	# give up
	return undef;
}

sub _get_lucky {
	my ($parser,$thing) = @_;
	my $tag;

	while ($tag = $parser->get_tag('a')) {
		if ($tag->[1]->{name}) {
			last if $tag->[1]->{name} =~ /mov/;
		}
	}
	$tag = $parser->get_tag('a');
	my ($id) = $tag->[1]->{href} =~ /(\d{7})/;

	return $id;
}

sub _id {
	my $parser = shift;
	my $tag;

	while ($tag = $parser->get_tag('a')) {
		if ($tag->[1]->{href}) {
			last if $tag->[1]->{href} =~ /Details/;
		}
	}
	my ($id) = $tag->[1]->{href} =~ /Details\?(\d{7})/;

	return $id;
}

sub _image {
	my $parser = shift;
	my ($tag,$image);

	while ($tag = $parser->get_tag('img')) {
		$tag->[1]->{alt} ||= '';
		if ($tag->[1]->{alt} eq 'cover') {
			$image = $tag->[1]->{src};
			last;
		}
		elsif ($tag->[1]->{alt} =~ /No poster/i) {
			last;
		}
	}

	return $image;
}

sub _director {
	my $parser = shift;
	my ($tag,@director);

	# skip
	$parser->get_tag('br');
	{
		$tag = $parser->get_tag();
		last unless $tag->[0] eq 'a';
		last if $parser->get_text eq '(more)';
		my ($director) = $tag->[1]->{href} =~ /\?(.*)$/;
		$director =~ tr/+/ /;
		$director =~ s/%([\dA-Fa-f]{2})/pack("C",hex($1))/eg;
		push @director,$director;
		$parser->get_tag('br');
		redo;
	}

	return [ unique(@director) ];
}

sub _genre {
	my $parser = shift;
	my ($tag,@genre);

	# skip
	while ($tag = $parser->get_tag('b')) {
		if ($tag->[1]->{class}) {
			last if 'ch' eq $tag->[1]->{class};
		}
	}

	while ($tag = $parser->get_tag('a')) {
		my $genre = $parser->get_text();
		last unless $tag->[1]->{href} =~ /Genres/;
		last if $genre =~ /more/;
		push @genre,$genre;
	}

	return [ unique(@genre) ];
}

sub _get_toker {
	my $url = URL . "?" . shift();
	my $content = get($url) or carp "can't connect to server";
	return HTML::TokeParser->new(\$content);
}

sub unique {
	my %seen;
	grep(!$seen{$_}++, @_);
}


1;

=pod

=head1 NAME

IMDB.pm - module to fetch movie info from www.imdb.com

=head1 DESCRIPTION

This is a module that uses LWP and HTML::TokeParser to
parse the web page for the requested movie. You can use
an IMDB identification number or the name of the movie.
IMDB.pm will try to return the best match.

=head1 SYNOPSIS

  use strict;
  use IMDB::Movie;

  my $movie = IMDB::Movie->new('78748');
  print join("|",
    $movie->title, 
    $movie->id, 
    $movie->year, 
    join(';',@{$movie->director}),
    join(';',@{$movie->writer}),
    join(';',@{$movie->genre}),
  ), "\n";

=head1 AUTHOR 

Jeffrey Hayes Anderson <captvanhalen@yahoo.com>

=head1 COPYRIGHT

Copyright (c) 2003 Jeffrey Hayes Anderson.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

=cut
