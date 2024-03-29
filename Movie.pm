package IMDB::Movie;

use strict;
use vars qw($VERSION $AUTOLOAD @MATCH);

use Carp;
use LWP::Simple;
use HTML::TokeParser;
use Data::Dumper;

$VERSION = '0.12';

sub new {
	my ($class,$id,$site) = @_;
	chomp($id);
	carp "can't instantiate $class without id or keyword" unless $id;
	$id = sprintf("%07d",$id) unless length($id) == 7 or $id =~ /\D/;
	$site ||= 'www';

	my $parser = _get_toker($id,$site);
	my ($title,$year);

	# get the ball rolling here
	($parser,$title,$year) = _title_year($parser,$id,$site);

	$title =~ tr/"//d;

	# need better way to handle errors, maybe?
	carp "$id turned up no matches" unless $parser;

	my $self = {
		title       => $title,
		year        => $year,
		id          => _id($parser),
		img         => _image($parser),
		directors   => _person($parser),
		writers     => _person($parser),
		genres      => _genre($parser),
		user_rating => _user_rating($parser),
		cast        => _cast($parser),
		matches     => \@MATCH,
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

sub as_HTML_Template {
	my $self = shift;
	require('Clone.pm');
	my $clone = Clone::clone($self);
	my %d = %{$clone->directors};
	my %w = %{$clone->writers};
	my %c = %{$clone->cast};
	$clone->{directors} = [ sort{$a->{id}<=>$b->{id}} values %d ];
	$clone->{writers}   = [ sort{$a->{id}<=>$b->{id}} values %w ];
	$clone->{cast}      = [ sort{$a->{id}<=>$b->{id}} values %c ];
	$clone->{genres}    = [ map {name => $_}, @{$clone->genres} ];
	return %$clone;
}

sub director { shift->_merge_names('directors') }
sub writer   { shift->_merge_names('writers') }

sub AUTOLOAD {
	my ($self) = @_;
	$AUTOLOAD =~ /.*::(\w+)/ && exists $self->{$1} and return $self->{$1};
	croak "No such attribute: $1";
}

sub DESTROY {}

############################################################################

sub _merge_names { [sort map "$_->{last_name}, $_->{first_name}", values %{shift->{+shift}} ] }

sub _title_year {
	my ($parser,$id,$site) = @_;
	my ($title,$year);

	$parser->get_tag('title');
	$title = $parser->get_text();

	if ($title eq 'IMDb name and title search') {
		$id = _get_lucky($parser);

		# start over
		$parser = _get_toker($id,$site);
		$parser->get_tag('title');
		$title = $parser->get_text();
	}

	return ($parser,$1,$2) if $title =~ /([^\(]+)\s+\((\d{4})/;

	# give up
	return undef;
}

sub _get_lucky {
	my ($parser) = @_;
	my ($tag,$id);

	while ($tag = $parser->get_tag('a')) {
		my $href = $tag->[1]->{href};
		next unless $href;
		if (($id) = $href =~ /\/title\/tt(\d{7})/) {
			push @MATCH, {id => $id, title => $parser->get_text};
		}
	}

	return $MATCH[0]{id};
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

sub _person {
	my $parser = shift;
	my ($tag,%name);

	# skip
	$parser->get_tag('br');
	{
		$tag = $parser->get_tag();
		last unless $tag->[0] eq 'a';

		my $name = $parser->get_text;
		last if $name eq '(more)';
		
		my ($id) = $tag->[1]{href} =~ /(\d+)/;
		$name = reverse $name;
		my ($l,$f) = map { scalar reverse $_} split(' ',$name,2);

		$name{$id} = { id => $id, last_name => $l, first_name => $f };

		$parser->get_tag('br');
		redo;
	}

	return {%name};
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

sub _cast {
	my $parser = shift;
	my ($tag,%name);

	# skip
	while ($tag = $parser->get_tag('b')) {
		if ($tag->[1]{class}) {
			last if $tag->[1]{class} eq 'blackcatheader';
		}
	}

	while ($tag = $parser->get_tag('a')) {
		my $href = $tag->[1]{href};
		if ($href) {
			if ($href eq 'fullcredits') {
				last;
			} else {
				my ($id) = $href =~ /\/name\/nm(\d+)/;
				if ($id) {
					my $name = $parser->get_text;
					$name = reverse $name;
					my ($l,$f) = map { scalar reverse $_} split(' ',$name,2);
					$name{$id} = { id => $id, last_name => $l, first_name => $f };
				}
			}
		}
	}
	return {%name};
}

sub _get_toker {
	my ($id,$site) = @_;
	my $title_url = "http://$site.imdb.com/title/tt";
	my $find_url  = "http://$site.imdb.com/Find?select=All&for=";
	my $url = ($id =~ /\D/)
		? $find_url  .$id
		: $title_url . $id
	;

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

  my $movie = IMDB::Movie->new(92610);
  print join("|",
    $movie->title, 
    $movie->id, 
    $movie->year, 
    join(';',@{$movie->director}),
    join(';',@{$movie->writer}),
    join(';',@{$movie->genres}),
    $movie->user_rating,
    $movie->img,
  ), "\n";

  sleep 5;

  # now more compatible with HTML::Template!
  $tmpl->param($movie->as_HTML_Template);

=head1 METHODS 

=over 4

=item B<new>

  my $movie_by_id = IMDB::Movie->new(92610);

  my $movie_by_title = IMDB::Movie->new('Bad Taste');

Instantiates the object and fetches the movie. IMDB::Movie prefers
the IMDB identification number, but you can pass the name of the
movie with moderate success. Note that this causes an extra page
fetch as IMDB::Movie parses the search results.

You can also specify which 'site' you want to search:

  my $movie = IMDB::Movie->new('Alien','uk');

This will search B<uk.imdb.com> instead of B<www.imdb.com>, the default.

=item B<title>

  my $title = $movie->title;

Returns the IMDB given title of this movie.

=item B<id>

  my $id = $movie->id;

Returns the IMDB id of this movie.

=item B<year>

  my $year = $movie->year;

Returns the year the movie was released.

=item B<director>

  my @director = @{$movie->director};

Returns an anonymous array reference of director names.

=item B<directors>

  my %director = %{$movie->directors};
  for my $id (keys %director) {
     print $director{$id}{first_name};
     print $director{$id}{last_name};
  }

Returns an anonymous hash reference whose keys are IMDB
name id's and whose values are anonymous hash references
containing first and last name key/value pairs.

=item B<writer>

  my @writer = @{$movie->writer};

Returns an anonymous array reference of writer names.

=item B<writers>

  my %writer = %{$movie->writers};
  for my $id (keys %writer) {
     print $writer{$id}{first_name};
     print $writer{$id}{last_name};
  }

Return an anonymous hash reference whose keys are IMDB
name id's and whose values are anonymous hash references
containing first and last name key/value pairs.

=item B<cast>

  my %cast = %{$movie->cast};
  for my $id (keys %cast) {
     print $cast{$id}{first_name};
     print $cast{$id}{last_name};
  }

Return an anonymous hash reference whose keys are IMDB
name id's and whose values are anonymous hash references
containing first and last name key/value pairs.

This is for the First Billed cast only, that is, the module
parses out the name from the first page. Possibly in the
future i will parse out the entire crew, but it's doubtful.

=item B<genres>

  my @genres = @{$movie->genres};

Returns an anonymous array reference of genre names.

=item B<user_rating>

  my $user_rating = $movie->user_rating;

Returns the current IMDB user rating as is.

=item B<img>

  my $img = $movie->img;

Returns the url of the image used for this Movie at imdb.com

=item B<matches>

  my @match = @{$movie->matches};

Returns a list of hashes (LoH) containing 'id' and 'title'
key/value pairs for all title matches returned when a seach
by title was performed. For example:

  use IMDB::Movie;
  use CGI qw(:standard);
  my $movie = IMDB::Movie->new('Terminator');
  my @match = @{$movie->matches};

  if (@match) {
     print (
        p('The following matches were found:'),
        ol(
           li([ map
              a(
                 {href => "http://imdb.com/title/tt$_->{id}"},
                 $_->{title}
              ), @match
           ])
        ),
     );
  }

will produce an HTML ordered list of anchored links.

=item B<as_HTML_Template>

  my %t_movie = $movie->as_HTML_Template;

This simply returns a hash that is a clone of the IMDB::Movie object.
The only difference between the clone and the original is the
clone's directors, writers, and genres methods return HTML::Template
ready data structures. Just use Data::Dumper and see the ouput
for yourself - if you use HTML::Template, you'll know what to do
with it.

=back

=head1 BUGS

If you have found a bug, typo, etc. please visit Best Practical Solution's
CPAN bug tracker at http://rt.cpan.org:

E<lt>http://rt.cpan.org/NoAuth/Bugs.html?Dist=IMDB-MovieE<gt>

or send mail to E<lt>bug-IMDB-Movie#rt.cpan.orgE<gt>

(you got this far ... you can figure out how to make that
a valid address ... and note that i won't respond to bugs
sent to my personal address any longer)

=head1 AUTHOR 

Jeffrey Hayes Anderson

=head1 CREDITS

Various suggestions and typo spottings:

   - Danilo Aghemo
   - ArteQ 2
   - Marvin Baschangel
   - V. Ray Krebs III
   - Codrut C. Racosanu

=head1 DISCLAIMER

This module should be used VERY SPARSLEY. The good people at
the Internet Movie Database provide access to their websites
for free, and i do not want this module to be used in an
irresponsible manor.

Also, screen-scraping a web site does not make for a long living
application. Any changes to IMDB's design could potentially break
this module. I give no garuantee that i will maintain this module,
but i will garuantee that i may just delete this module with no
notice. 

=head1 COPYRIGHT

Movie Data Copyright (c) 1990-2004 Internet Movie Database Inc.

Module Copyright (c) 2004 Jeffrey Hayes Anderson.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

=cut
