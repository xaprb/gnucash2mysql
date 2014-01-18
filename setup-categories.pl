#!/usr/bin/perl

# This is gnucash2mysql's category setup script version $Revision: 1.3 $.
# 
# THIS PROGRAM IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
# MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
# 
# This program is copyright (c) 2006 Baron Schwartz, baron at xaprb dot com.
# All rights reserved.  Feedback and improvements are gratefully received.

use strict;
use warnings FATAL => 'all';

use Data::Dumper;
use DBI();
use English qw(-no_match_vars);
use Getopt::Long;
use Term::ReadLine;

our $VERSION = sprintf "%d.%03d", q$Revision: 1.3 $ =~ /(\d+)/g;

# ############################################################################
# Get configuration information.
# ############################################################################

my %opt_spec = (
   d => { s => 'database|d=s',  d => 'Database' },
   h => { s => 'host|h=s',      d => 'Database server hostname' },
   o => { s => 'port|P=i',      d => 'Database server port' },
   p => { s => 'pass|p=s',      d => 'Database password' },
   u => { s => 'user|u=s',      d => 'Database username' },
   l => { s => 'help',          d => 'Show this help message' },
   r => { s => 'refresh|r',     d => 'Only do categories that are assigned' },
   i => { s => 'ignore|i=s',    d => 'Ignore categories like this' },
# TODO: do all
);

# For ordering them the way I want...
my @opt_keys = qw( h d o u p r i l );

my %opts = (
   d => '',
   h => '',
   o => 0,
   p => 0,
   u => '',
   l => 0,
   r => 0,
   i => '',
);

Getopt::Long::Configure('no_ignore_case', 'bundling');
GetOptions( map { $opt_spec{$_}->{'s'} => \$opts{$_} }  @opt_keys );

$opts{'v'} ||= 1;
$opts{'n'} =   [ split(/,/, $opts{'n'} || '' ) ];

if ( $opts{'l'} ) {
   print "Usage: $PROGRAM_NAME <options> <file>\n\n  Options:\n\n";
   foreach my $key ( @opt_keys ) {
      my ( $long, $short ) = $opt_spec{$key}->{'s'} =~ m/^(\w+)(?:\|([^=]*))?/;
      $long  = "--$long" . ( $short ? ',' : '' );
      $short = $short ? " -$short" : '';
      printf("  %-13s %-4s %s\n", $long, $short, $opt_spec{$key}->{'d'});
   }
   print <<USAGE;

$PROGRAM_NAME sets up your databased GnuCash categories.

If possible, database options are read from your .my.cnf file.
For more details, please read the documentation.

USAGE
   exit(1);
}

my $conn = {
   h  => $opts{'h'},
   db => $opts{'d'},
   u  => $opts{'u'},
   p  => $opts{'p'},
   o  => $opts{'o'},
};

if ( grep { !$conn->{$_} } keys %$conn ) {
   # Try to use the user's .my.cnf file.
   eval {
      open my $conf_file, "<", "$ENV{HOME}/.my.cnf" or die $OS_ERROR;
      while ( my $line = <$conf_file> ) {
         next if $line =~ m/^#/;
         my ( $key, $val ) = split( /=/, $line );
         next unless defined $val;
         chomp $val;
         if ( $key eq 'host' )     { $conn->{'h'}  ||= $val; }
         if ( $key eq 'user' )     { $conn->{'u'}  ||= $val; }
         if ( $key =~ m/^pass/ )   { $conn->{'p'}  ||= $val; }
         if ( $key eq 'database' ) { $conn->{'db'} ||= $val; }
         if ( $key eq 'port' )     { $conn->{'o'}  ||= $val; }
      }
      close $conf_file;
   };
   if ( $EVAL_ERROR && $EVAL_ERROR !~ m/No such file/ ) {
      print "I tried to read your .my.cnf file, but got '$EVAL_ERROR'\n";
   }
}

# Fill in defaults for some things
$conn->{'o'} ||= 3306;
$conn->{'h'} ||= 'localhost';
$conn->{'u'} ||= getlogin() || getpwuid($UID);
$conn->{'p'} ||= '';

my %prompts = (
   o  => "\nPort number: ",
   h  => "\nDatabase host: ",
   u  => "\nDatabase user: ",
   p  => "\nDatabase password: ",
   db => "\nDatabase: ",
);

# If anything remains, prompt the terminal
while ( my ( $thing ) = grep { !$conn->{$_} } keys %$conn ) {
   $conn->{$thing} = prompt($prompts{$thing}, $thing eq 'p');
}

# ############################################################################
# Get ready to do the main work.
# ############################################################################


# Connect to the database
my $dbh = DBI->connect(
   "DBI:mysql:database=$conn->{db};host=$conn->{h};port=$conn->{o}",
   $conn->{'u'}, $conn->{'p'}, { AutoCommit => 1, RaiseError => 1, PrintError => 0 } )
   or die("Can't connect to DB: $!");

my $sth = $dbh->prepare("
    replace into account_category(account, category) values (?, ?);");

my $query = "
   select a.id, a.type, a.parent, a.name, a.description, c.category
   from account as a
      left outer join account_category as c on a.id = c.account";
if ( $opts{r} ) {
   $query =~ s/left outer/inner/;
}

my $accounts = $dbh->selectall_hashref($query, 'id');

print "Enter a category for each account:\n";

# Instead of building and navigating a tree, I just tell each account where it
# is in the hierarchy, and then sort by that.
foreach my $account ( values %$accounts ) {
   $account->{'path'} = build_hierarchy($account);
}

my $term = Term::ReadLine->new('Test');
$term->Attribs->{completion_function} = sub {
   my ( $text, $line, $start ) = @_;
   return @{$dbh->selectcol_arrayref('select distinct category from account_category')};
};

foreach my $account (
   sort {$a->{'path'} cmp $b->{'path'} } values %$accounts )
{
   map { $account->{$_} ||= '' } qw(type category parent name description);
   next if $opts{i} && $account->{path} =~ m/$opts{i}/;
   if ( ( grep { $_ eq $account->{'type'}} qw(EXPENSE ASSET LIABILITY))
         && !$account->{'is_placeholder'}
         && ($opts{r} || !$account->{'category'})
      )
   {
      print $account->{'path'};
      my $answer = $term->readline('Category: ', $account->{category});
      $sth->execute($account->{'id'}, $answer) if $answer;
   }
}

sub build_hierarchy {
   my $account = shift;
   my @hierarchy = $account;
   my $cur_account = $account;
   while ( $cur_account && $cur_account->{'parent'} ) {
      $cur_account = $accounts->{$cur_account->{'parent'}};
      if ( $cur_account ) {
         unshift @hierarchy, $cur_account;
      }
   }

   my $level = 0;
   my $result = "";
   foreach ( @hierarchy ) {
      $result .= ( "   " x $level ) . "`-+" . $_->{'name'} . "\n";
      $level++;
   }
   return $result;
}

$dbh->disconnect;
