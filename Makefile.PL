use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'		   => 'IMDB::Movie',
    'VERSION_FROM' => 'Movie.pm',
    'PREREQ_PM'    => {
		'LWP::Simple'      => 1.36,
		'HTML::TokeParser' => 2.24,
	}, 
);
