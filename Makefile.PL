use ExtUtils::MakeMaker;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
   'NAME'         => 'gnucash2mysql',
   'VERSION_FROM' => 'gnucash2mysql',     # finds $VERSION
   'EXE_FILES'    => ['gnucash2mysql'],
   'PREREQ_PM'    => {
      Term::ReadKey      => 2.10,
      Term::ProgressBar  => 2.09,
      XML::Parser::Expat => 2.34,
      DBI                => 1.13,
      DBD::mysql         => 1.0,
   },
   'LIBS'   => [''],                      # e.g., '-lm'
   'DEFINE' => '',                        # e.g., '-DHAVE_SOMETHING'
   'INC'    => '',                        # e.g., '-I/usr/include/other'
);
