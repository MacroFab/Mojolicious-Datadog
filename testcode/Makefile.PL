use ExtUtils::MakeMaker;

WriteMakefile(
    NAME              => 'MFab::MyModule',
    VERSION_FROM      => 'lib/MFab/MyModule.pm',
    PREREQ_PM         => {
        'Test::More' => 0,
    },
    ABSTRACT_FROM     => 'lib/MFab/MyModule.pm',
    AUTHOR            => 'Your Name',
    LICENSE           => 'perl',
    MIN_PERL_VERSION  => '5.010',
);
