use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'		   => 'IMDB::Movie',
    'VERSION_FROM' => 'Movie.pm',
    'PREREQ_PM'    => {
		'Test::More'       => 0.47,
		'LWP::Simple'      => 1.36,
		'HTML::TokeParser' => 2.24,
		'Clone'            => 0.15,
	}, 
);
