package IMDB::Movie;

use strict;
use vars qw($VERSION $AUTOLOAD);

use Carp;
use LWP::Simple;
use HTML::TokeParser;
use Data::Dumper;

$VERSION = '0.05';
use constant URL => 'http://www.imdb.com/title/tt';

sub new {
	my ($class,$id) = @_;
	carp "can't instantiate $class without id or keyword" unless $id;
	$id = sprintf("%07d",$id) unless length($id) == 8;
	#warn "fetching $id\n";

	my $parser = _get_toker($id);
	my ($title,$year);

	# get the ball rolling here
	($parser,$title,$year) = _title_year($parser,$id);

	$title =~ tr/"//d;

	# need better way to handle errors, maybe?
	carp "$id turned up no matches" unless $parser;

	my $self = {
		title       => $title,
		year        => $year,
		id          => _id($parser),
		img         => _image($parser),
		directors   => _director($parser),
		writers     => _director($parser),
		genres      => _genre($parser),
		user_rating => _user_rating($parser),
	};
	#print STDERR Dumper $self;
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

sub as_HTML_Template {
	my $self = shift;
	require('Clone.pm');
	my $clone = Clone::clone($self);
	$clone->{directors} = [ map {name => $_}, @{$clone->directors} ];
	$clone->{writers}   = [ map {name => $_}, @{$clone->writers} ];
	$clone->{genres}    = [ map {name => $_}, @{$clone->genres} ];
	return %$clone;
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
	my ($id,$tag);

	while ($tag = $parser->get_tag('select')) {
		if ($tag->[1]->{name}) {
			($id) = $tag->[1]->{name} =~ /(\d+)/;
			last if $id;
		}
	}
	
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
	my ($tag,@name);

	# skip
	$parser->get_tag('br');
	{
		$tag = $parser->get_tag();
		last unless $tag->[0] eq 'a';

		my $name = $parser->get_text;
		last if $name eq '(more)';
		
		$name = reverse $name;
		my ($l,$f) = map { scalar reverse $_} split(' ',$name,2);
		push @name, "$l, $f";
		$parser->get_tag('br');

		redo;
	}

	return [ unique(@name) ];
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

sub _user_rating {
	my $parser = shift;
	my $tag;

	while ($tag = $parser->get_tag('a')) {
		if ($tag->[1]->{href}) {
			last if $tag->[1]->{href} eq 'ratings';
		}
	}
	$tag = $parser->get_tag('b');
	my ($rating) = split('\/',$parser->get_text,2);
	return $rating;
}

sub _get_toker {
	my $url = URL . shift;
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
    $movie->user_rating,
    $movie->img,
  ), "\n";

  sleep 5;

  # now more compatible with HTML::Template!
  $tmpl_param->($movie->as_HTML_Template);

=head1 METHODS 

=over 4

=item B<title>

  my $title = $movie->title;

Returns the IMDB given title of this movie.

=item B<id>

  my $id = $movie->id;

Returns the IMDB id of this movie.

=item B<year>

  my $year = $movie->year;

Returns the year the movie was released.

=item B<directors>

  my @directors = @{$movie->directors};

Return an anymous array reference of director(s).

=item B<writers>

  my @writers = @{$movie->writers};

Return an anymous array reference of writer(s).

=item B<genres>

  my @genres = @{$movie->genres};

Return an anymous array reference of genre(s).

=item B<user_rating>

  my $user_rating = $movie->user_rating;

Returns the current IMDB user rating as is.

=item B<img>

  my $img = $movie->img;

Returns the url of the image use for this Movie at imdb.com

=item B<as_HTML_Template>

  my %t_movie = $movie->as_HTML_Template;

This simply returns a hash that is a clone of the IMDB::Movie object.
The only difference between the clone and the original is the
clone's directors, writers, and genres methods return HTML::Template
ready data structures. Just use Data::Dumper and see the ouput
for yourself - if you use HTML::Template, you'll know what to do
with it.

=back

=head1 AUTHOR 

Jeffrey Hayes Anderson <captvanhalen@yahoo.com>

=head1 DISCLAIMER

This module should be used VERY SPARSLEY. The good people at
the Internet Movie Database provide access to their websites
for free, and i do not want this module to be used in an
irresponsible manor.

Also, screen-scraping a web site does not make for a long living
application. Any changes to IMDB's design could potentially break
this module. I give no garuantee that i will maintain this module,
but i will garuantees that i may just delete this module with no
notice. 

=head1 COPYRIGHT

Module Copyright (c) 2003 Jeffrey Hayes Anderson.

Movie Data Copyright (c) 1990-2003 Internet Movie Database Inc.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

=cut
