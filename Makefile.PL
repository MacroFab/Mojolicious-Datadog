use ExtUtils::MakeMaker;

WriteMakefile(
    NAME              => 'MFab::Plugins::Datadog',
    VERSION_FROM      => 'lib/MFab/Plugins/Datadog.pm',
    PREREQ_PM         => {
        'Test::More' => 0,
    },
    ABSTRACT_FROM     => 'lib/MFab/Plugins/Datadog.pm',
    AUTHOR            => 'Daniel Drown',
    LICENSE           => 'perl',
    MIN_PERL_VERSION  => '5.010',
);
