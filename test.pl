use Test::More qw(no_plan);

require_ok('Movie');

print "connect to imdb.com server? [y]: ";
chomp($ans = <STDIN>);
exit if $ans =~ /^(q|n)/i;

$movie = IMDB::Movie->new(78748);
isa_ok($movie,'IMDB::Movie');
is($movie->id,'0078748','right id');
is($movie->title,'Alien','right title');
is($movie->year,1979,'right year');
like($movie->user_rating,qr/\d+\.?\d*/,"got a user_rating: " . $movie->user_rating);
is_deeply($movie->directors,['Scott, Ridley'],'right directors');
is_deeply($movie->writers,['O\'Bannon, Dan','Shusett, Ronald'],'right writers');
is_deeply($movie->genres, ['Sci-Fi','Horror','Thriller','Action'],'right genres');

%tmpl = $movie->as_HTML_Template;
is_deeply($tmpl{directors},[{name=>'Scott, Ridley'}],'correct HTML::Template format');
is_deeply($movie->directors,['Scott, Ridley'],'deep copy successful');
