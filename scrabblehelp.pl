#!/usr/bin/perl 

use strict;
use Data::Dumper;

my $VERSION = '0.8b';
# Updates:
# 0.8b
# _X_ Updating values for WWF.  Keep old table around and make it CLI
#     -switchable
# _X_ Add action to check for single-letter bingos => capital B
#     i.e., for given rack, check [a-z] for ones that give bingo completion
# _X_ more forgiving input - wipe leading/trailing whitespace; non-special
#     capital letters are ok

# Would like:
# - Keep input in a stack, and allow up/down to cycle through and edit.
# - alongside matching.  need syntax for 'matches $var'.
#   i.e  ^o.>e means start with o, next letter has to match ^.e$
#   maybe {>e}?
# - Score optimization for triple/double letters
# - Score optimization for triple/double words

# - hello?  brainstorm?  use CAPITALS for rack letters, lowercase for board letters.
# - duh.  why was that so freakin' hard?
#
# Scrabble helper.  Reads in words from a file.
# First milestone is being able to just print all the 
#      words from %words that can be made from the given tiles.
#      COMPLETE
# Second milestone is being able to use an arbitrary regex to match against,
#      returning only words that can be constructed with $tiles
#      Update:  enclosing a letter in () will mean this is a non-board tile.
#      COMPLETE
#      Note:  The regex checking isn't real strict.  I only allows \d's so you
#             can use {x,y} notation, for example, but it's not strictly
#             limited to that usage.  You MAY shoot yourself in the foot.
#      Note:  Things I support:
#               ^, $, ?, ., {x,y} notation
#              (x) indicates this is the x from your tiles, not a board tile.
#              Multiple non-board tiles must be specified like
#               (q)(u) not (qu). 

# Third milestone will be to support blanks
#      Blanks will be denoted as '*'
#   Complete!

# Next thing:  restart with tiles without restarting:
#    - Type in 'R' for the board configuration.

# Other miscellany:  Want to be able to support syntax in the regex we input
#      that expands to match only letters we have available that complete 
#      crosswords.  Not sure how to notate this.

# Specify dictionary on commandline
my $wfile = shift;
    die "Couldn't find $wfile\n" unless -f $wfile;

# The words will be held in %words
my %words = ();
my $tiles = '';

# my %values = (
#     a =>  1, b =>  3, c =>  3, d =>  2,
#     e =>  1, f =>  4, g =>  2, h =>  4,
#     i =>  1, j =>  8, k =>  5, l =>  1,
#     m =>  3, n =>  1, o =>  1, p =>  3,
#     q => 10, r =>  1, s =>  1, t =>  1,
#     u =>  1, v =>  4, w =>  4, x =>  8,
#     y =>  4, z => 10 
#     );

my %values = (
    a =>  1, b =>  4, c =>  4, d =>  2,
    e =>  1, f =>  4, g =>  3, h =>  3,
    i =>  1, j => 10, k =>  5, l =>  2,
    m =>  4, n =>  2, o =>  1, p =>  4,
    q => 10, r =>  1, s =>  1, t =>  1,
    u =>  2, v =>  5, w =>  4, x =>  8,
    y =>  3, z => 10 
    );

# Read in the word list:
print " * Reading $wfile :";
open ( WORDS, "<$wfile" ) or die "Couldn't open $wfile\n$!";
    while ( my $line = <WORDS> ) {
        chomp $line;
        $line =~ s/\s//g;
        $line =  lc($line);
        $words{$line}++;
    }
close ( WORDS );
print " [OK]\n";

my $regex_regex = qr/^\s*([a-z\.\^\$\[\]\(\)\?\*])+\s*$/;

# Main event loop:
TILES : while ( 1 ) {

    # Read in tiles:
    my $tmp = '';
    until ( $tmp =~ m/^\s*([a-zA-Z\s\*])+\s*$/ ) {
        print " Input your tiles -> ";
        $tmp = <STDIN>;
        chomp $tmp;
        $tmp =~ s/\s//g;
    }
    $tiles = $tmp;

    while ( 1 ) {

        # Get board pattern to match
        my $tmp2 = '';
        until ( $tmp2 =~ m/$regex_regex/ ) {
            print "\n Input board tile pattern -> ";
            $tmp2 = <STDIN>;
            chomp $tmp2;
            $tmp2 =~ s/\s//g;
            next TILES if ( $tmp2 =~ m/^R$/ );

            # Get one-away bingos
            if ( $tmp2 =~ m/^B$/ ) {

                my $bingos = get_bingos ( tiles => $tiles );
                # $bingos = {
                #               'a' => 'whatever (38 pts)';
                #           }
                if ( scalar ( keys %{ $bingos } ) ) {
                    print "Sweet! One-away bingos:\n";    
                    foreach my $l ( keys %{$bingos} ) {
                        foreach my $match ( keys %{ $bingos->{$l} } ) {
                            print "$l: ($bingos->{$l}{$match}) - $match\n";
                        }
                    }
                } else {
                    print "Sorry! No one-away bingos\n";
                }
                print "\n\n";

            }
        }

        my $board_pattern = $tmp2;

        print "\n * For Tiles : " . join ' ',
                                    split //,
                                    $tiles . "\n";

        print "     And board pattern: $board_pattern\n";

        my $matches    = get_matches ( tiles => $tiles,
                                       board => $board_pattern );

        my $matchcount = scalar ( keys %{ $matches } );

        print " * Found $matchcount matches\n";
        print "   Printing first 25 matches:\n";

        my $c = 0;
        MATCH : foreach my $match ( sort  { ${ $matches }{ $b }
                                        <=> ${ $matches }{ $a } }
                                    keys    %{ $matches }     ) {

            print "($matches->{$match}) - $match\n";
            last MATCH if ++$c > 25;
        }

    }

}

sub get_bingos {
    # valid options:
    # tiles      => string of your tiles
    die "Odd number of parameters to get_matches" if ($#_ % 2) != 1;
    my %opts = @_;
    return undef unless ( defined $opts{tiles} );
    return undef unless ( $opts{tiles} =~ m/^([a-z\*])+$/ );

    my %bingos = ();
    foreach my $l ( 'a' .. 'z' ) {

        my $matches = get_matches( tiles => $tiles,
                                   board => $l     );

        if ( scalar ( keys %{ $matches } ) ){
            foreach my $match ( keys %{$matches} ) {
                if ( $match =~ m/^.{8}/ ) {
                    $bingos{$l}{$match} = $matches->{$match};
                }
            }
        }
    }

    return \%bingos;
}


sub get_matches {

    # valid options:
    # tiles      => string of your tiles
    # board      => string of pattern on board to match.
    # min_length => minimum size of words to include
    # max_length => maximum size of words to include

    # Strategy:
    # - First narrow down the list of %words by excluding those that include any
    #   letters we don't consider valid (non tile letters, at first)
    # - Then eliminate any words requiring more of a GOOD letter than we have.

    die "Odd number of parameters to get_matches" if ($#_ % 2) != 1;
    my %opts = @_;
    return undef unless ( defined $opts{tiles} );
    return undef unless ( $opts{tiles} =~ m/^([a-z\*])+$/ );

    my $minsize = 2;
    my $maxsize = 25;
    my $board   = '';

    ###################
    # Process Options #
    ###################
    if ( defined $opts{min_length} ){
        if ( $opts{min_length} =~ m/^\d+$/ ) {
            $minsize = $opts{min_length};
        }
    }

    if ( defined $opts{max_length} ){
        if ( $opts{max_length} =~ m/^\d+$/ ) {
            $maxsize = $opts{max_length};
        }
    }

    my @mytiles = ();
    if ( defined $opts{board} ){
        if ( $opts{board} =~ m/$regex_regex/ ) {
            
            # Need to store the letters to not count twice:
            if ( $opts{board} =~ m/\([a-z]\)/ ) {
                @mytiles = $opts{board} =~ m/\(([a-z])\)/g;
                $opts{board} =~ s/[\(\)]//g;
            }

            
            $board = $opts{board}; 
        }
    }

    ##################################################
    # Make a count of the letters we have available, #
    # And a list of those unavailable                #
    ##################################################
    my %count = ();
    my @inverted = ();

    my $blanks =()= $opts{tiles} =~ m/(\*)/g;

    foreach my $l ( keys %values ) {
        $count{$l}     =()= $tiles  =~ m/($l)/g;
        my $boardcount =()= $board  =~ m/($l)/g;
        $count{$l}     +=   $boardcount;
        push @inverted, $l unless $count{$l};
    }

    #######################################
    # Don't count the ()'d letters twice: #
    #######################################
    foreach my $t ( @mytiles ) {
        $count{$t} -- if ( $count{$t} > 0 );
    }

    my $bad_letters = join //, @inverted;

    # Actual Word Processing:

    ##########################################################
    # First eliminate the words that have any of the letters #
    # we don't have on hand : (how many negatives is that?)  #
    ##########################################################
    my @matches = ();
    if ( $blanks > 0 ) {
        @matches = keys %words;
    } else {
        @matches = grep { $_ !~ m/[$bad_letters]/ } keys %words;
    }

    ####################################################
    # Go to work on all those not already eliminated:  #
    ####################################################
    my %matches = ();
    WORD : foreach my $word ( @matches ) {

        my $blank_tiles   = $blanks;  # reinit on each word.
        my $blanks_in_use = '';       # reinit on each word.

        # Don't bother parsing if it's not between min/max size:
        next WORD unless $word =~ m/.{$minsize,$maxsize}/;
           
        # This *REALLY* speeds things up:
        if ( $board =~ m/\S/ ) {
            next WORD unless ( $word =~ m/$board/i );
        }

        # Throw out the ones that have more of any
        # letter than we have available:
        LETTER : foreach my $l ( keys %count ) {
            my $c =()= $word =~ m/($l)/g;
            if ( $c > $count{$l} ) {

                $blank_tiles -= ($c - $count{$l});

                # if we have more of letter X in this word
                # than we have tiles, we have to dip into our blanks!

                if ( $blank_tiles >= 0 ) {
                    #print "Debug: Continuing with $word, using blank for an $l (down to $blank_tiles)\n";
                    $blanks_in_use .= $l;
                    next LETTER;
                } else {
                    #print "   Debug: Threw out $word, didn't have enough $l\n";
                    next WORD;
                }

            } else {
                next LETTER;
            }
        }


        # TODO
        # This needs work:
        #  - add a bingo bonus; need to know how many tiles from the board we used
        #  

        $matches{$word} = score($word) - ( ( $blanks_in_use =~ m/\S/ )
                                           ? score($blanks_in_use)
                                           : 0 );

    }

    return \%matches;
}

sub score {
    my $word = shift;
       $word =~ s/\s//g;
       $word = lc $word;

    die "You gave score() a bad word, '$word'\n" 
        unless ( $word =~ m/^[a-z]+$/ );

    my $score = 0;
    foreach my $letter ( split //, $word ) {
        $score += $values{$letter};
    }

    return $score;
}
