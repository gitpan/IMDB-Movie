#use Test::More qw(no_plan);
use Test::More tests => 13;

require_ok('Movie');

print "connect to imdb.com server? [y]: ";
chomp($ans = <STDIN>);
exit if $ans =~ /^(q|n)/i;
print "This test's random movie (from list of 1 movie) will be 'Alien'...\n";

$movie = IMDB::Movie->new(78748);
isa_ok($movie,'IMDB::Movie');
is($movie->id,'0078748','right id');
is($movie->title,'Alien','right title');
is($movie->year,1979,'right year');
like($movie->user_rating,qr/\d+\.?\d*/,"got a user_rating: " . $movie->user_rating);
is_deeply($movie->directors,{'0000631'=>{qw(id 0000631 last_name Scott first_name Ridley)}},'strict: correct director');
is_deeply($movie->writer,['O\'Bannon, Dan','Shusett, Ronald'],'loose:  correct writers');
is_deeply($movie->genres, [qw(Sci-Fi Horror Thriller Action)],'normal: correct genres');

%tmpl = $movie->as_HTML_Template;
is_deeply($tmpl{directors}[0],{qw(id 0000631 last_name Scott first_name Ridley)},'HTML::Template correct director');
is_deeply($tmpl{writers}[0],{qw(id 0639321 last_name O'Bannon first_name Dan)},'HTML::Template correct writer 1');
is_deeply($tmpl{writers}[1],{qw(id 0795953 last_name Shusett first_name Ronald)},'HTML::Template correct writer 2');
is_deeply($movie->director,['Scott, Ridley'],'deep copy successful');
