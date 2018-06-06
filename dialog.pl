# Functions that handle calling dialog(1) -*-perl-*-
# $Id: dialog.pl,v 1.13 2018/06/06 01:47:24 tom Exp $
#
# The "rhs_" functions, as well as return_output originally came from Redhat
# 4.0, e.g.,
# http://www.ibiblio.org/pub/historic-linux/distributions/redhat-4.0/i386/live/usr/bin/Xconfigurator.pl
# The other functions were added to make this more useful for demonstrations.

# These comments are from the original file:
#------------------------------------------------------------------------------
# Return values are 1 for success and 0 for failure (or cancel)
# Resultant text (if any) is in dialog_result

# Unfortunately, the gauge requires use of /bin/sh to get going.
# I didn't bother to make the others shell-free, although it
# would be simple to do.

# Note that dialog generally returns 0 for success, so I invert the
# sense of the return code for more readable boolean expressions.
#------------------------------------------------------------------------------

use warnings;
use strict;
use diagnostics;

our $DIALOG = "dialog";
our $GAUGE;
our $gauge_width;
our $scr_lines = 24;
our @dialog_result;

require "flush.pl";

sub quoted($) {
    my $text = shift;
    $text =~ s/[\r\n]+/\n/g;
    $text =~ s/[^\n\t -~]/?/g;
    $text =~ s/([\\"])/\\$1/g;
    return sprintf "\"%s\"", $text;
}

sub rhs_clear {
    return system("$DIALOG --clear");
}

sub rhs_textbox {
    my ( $title, $file, $width, $height ) = @_;

    $width  = int($width);
    $height = int($height);
    system( "$DIALOG --title "
          . &quoted($title)
          . " --textbox $file $height $width" );

    return 1;
}

sub rhs_msgbox {
    my ( $title, $message, $width ) = @_;
    my ( $tmp, $height, $message_len );

    $width       = int($width);
    $message     = &rhs_wordwrap( $message, $width );
    $message_len = split( /^/, $message );
    $tmp         = $message;
    if ( chop($tmp) eq "\n" ) {
        $message_len++;
    }
    $height = 4 + $message_len;

    $tmp =
      system( "$DIALOG --title "
          . &quoted($title)
          . " --msgbox "
          . &quoted($message)
          . " $height $width" );
    if ($tmp) {
        return 0;
    }
    else {
        return 1;
    }
}

sub rhs_infobox {
    my ( $title, $message, $width ) = @_;
    my ( $tmp, $height, $message_len );

    $width       = int($width);
    $message     = &rhs_wordwrap( $message, $width );
    $message_len = split( /^/, $message );
    $tmp         = $message;
    if ( chop($tmp) eq "\n" ) {
        $message_len++;
    }
    $height = 2 + $message_len;

    return
      system( "$DIALOG --title "
          . &quoted($title)
          . " --infobox "
          . &quoted($message)
          . " $height $width" );
}

sub rhs_yesno {
    my ( $title, $message, $width ) = @_;
    my ( $tmp, $height, $message_len );

    $width       = int($width);
    $message     = &rhs_wordwrap( $message, $width );
    $message_len = split( /^/, $message );
    $tmp         = $message;
    if ( chop($tmp) eq "\n" ) {
        $message_len++;
    }
    $height = 4 + $message_len;

    $tmp =
      system( "$DIALOG --title "
          . &quoted($title)
          . " --yesno "
          . &quoted($message)
          . " $height $width" );

    # Dumb: dialog returns 0 for "yes" and 1 for "no"
    if ( !$tmp ) {
        return 1;
    }
    else {
        return 0;
    }
}

sub rhs_gauge {
    my ( $title, $message, $width, $percent ) = @_;
    my ( $tmp, $height, $message_len );

    $width       = int($width);
    $gauge_width = $width;

    $message = &rhs_wordwrap( $message, $width );
    $message_len = split( /^/, $message );
    $tmp = $message;
    if ( chop($tmp) eq "\n" ) {
        $message_len++;
    }
    $height = 5 + $message_len;

    open( $GAUGE,
            "|$DIALOG --title "
          . &quoted($title)
          . " --gauge "
          . &quoted($message)
          . " $height $width $percent" );
}

sub rhs_update_gauge {
    my ($percent) = @_;

    &printflush( $GAUGE, "$percent\n" );
}

sub rhs_update_gauge_and_message {
    my ( $message, $percent ) = @_;

    $message = &rhs_wordwrap( $message, $gauge_width );
    $message =~ s/\n/\\n/g;
    &printflush( $GAUGE, "XXX\n$percent\n$message\nXXX\n" );
}

sub rhs_stop_gauge {
    close $GAUGE;
}

sub rhs_inputbox {
    my ( $title, $message, $width, $instr ) = @_;
    my ( $tmp, $height, $message_len );

    $width       = int($width);
    $message     = &rhs_wordwrap( $message, $width );
    $message_len = split( /^/, $message );
    $tmp         = $message;
    if ( chop($tmp) eq "\n" ) {
        $message_len++;
    }
    $height = 7 + $message_len;

    return &return_output( 0,
            "$DIALOG --title "
          . &quoted($title)
          . " --inputbox "
          . &quoted($message)
          . " $height $width "
          . &quoted($instr) );
}

sub rhs_menu {
    my ( $title, $message, $width, $numitems ) = @_;
    my ( $i, $tmp, $ent, $height, $menuheight, @list, $message_len );

    $width    = int($width);
    $numitems = int($numitems);

    shift;
    shift;
    shift;
    shift;

    @list = ();
    for ( $i = 0 ; $i < $numitems ; $i++ ) {
        $ent         = shift;
        $list[@list] = &quoted($ent);
        $ent         = shift;
        $list[@list] = &quoted($ent);
    }

    $message = &rhs_wordwrap( $message, $width );

    $message_len = split( /^/, $message );
    $tmp = $message;
    if ( chop($tmp) eq "\n" ) {
        $message_len++;
    }

    $height = $message_len + 6 + $numitems;
    if ( $height <= $scr_lines ) {
        $menuheight = $numitems;
    }
    else {
        $height     = $scr_lines;
        $menuheight = $scr_lines - $message_len - 6;
    }

    return &return_output( 0,
            "$DIALOG --title "
          . &quoted($title)
          . " --menu "
          . &quoted($message)
          . " $height $width $menuheight @list" );
}

sub rhs_menul {
    my ( $title, $message, $width, $numitems ) = @_;
    my ( $i, $tmp, $ent, $height, $menuheight, @list, $message_len );

    $width    = int($width);
    $numitems = int($numitems);

    shift;
    shift;
    shift;
    shift;

    @list = ();
    for ( $i = 0 ; $i < $numitems ; $i++ ) {
        $ent         = shift;
        $list[@list] = &quoted($ent);
        $list[@list] = &quoted("");
    }

    $message = &rhs_wordwrap( $message, $width );

    $message_len = split( /^/, $message );
    $tmp = $message;
    if ( chop($tmp) eq "\n" ) {
        $message_len++;
    }

    $height = $message_len + 6 + $numitems;
    if ( $height <= $scr_lines ) {
        $menuheight = $numitems;
    }
    else {
        $height     = $scr_lines;
        $menuheight = $scr_lines - $message_len - 6;
    }

    return &return_output( 0,
            "$DIALOG --title "
          . &quoted($title)
          . " --menu "
          . &quoted($message)
          . " $height $width $menuheight @list" );
}

sub rhs_menua {
    my ( $title, $message, $width, %items ) = @_;
    my ( $tmp, $ent, $height, $menuheight, @list, $message_len );

    $width = int($width);
    @list  = ();
    foreach $ent ( sort keys(%items) ) {
        $list[@list] = &quoted($ent);
        $list[@list] = &quoted( $items{$ent} );
    }

    $message = &rhs_wordwrap( $message, $width );

    $message_len = split( /^/, $message );
    $tmp = $message;
    if ( chop($tmp) eq "\n" ) {
        $message_len++;
    }

    my $numitems = keys(%items);
    $height = $message_len + 6 + $numitems;
    if ( $height <= $scr_lines ) {
        $menuheight = $numitems;
    }
    else {
        $height     = $scr_lines;
        $menuheight = $scr_lines - $message_len - 6;
    }

    return &return_output( 0,
            "$DIALOG --title "
          . &quoted($title)
          . " --menu "
          . &quoted($message)
          . " $height $width $menuheight @list" );
}

sub rhs_checklist {
    my ( $title, $message, $width, $numitems ) = @_;
    my ( $i, $tmp, $ent, $height, $menuheight, @list, $message_len );

    $width    = int($width);
    $numitems = int($numitems);

    shift;
    shift;
    shift;
    shift;

    @list = ();
    for ( $i = 0 ; $i < $numitems ; $i++ ) {
        $ent         = shift;
        $list[@list] = &quoted($ent);
        $ent         = shift;
        $list[@list] = &quoted($ent);
        $ent         = shift;
        if ($ent) {
            $list[@list] = "ON";
        }
        else {
            $list[@list] = "OFF";
        }
    }

    $message = &rhs_wordwrap( $message, $width );

    $message_len = split( /^/, $message );
    $tmp = $message;
    if ( chop($tmp) eq "\n" ) {
        $message_len++;
    }

    $height = $message_len + 6 + $numitems;
    if ( $height <= $scr_lines ) {
        $menuheight = $numitems;
    }
    else {
        $height     = $scr_lines;
        $menuheight = $scr_lines - $message_len - 6;
    }

    return &return_output( "list",
            "$DIALOG --title "
          . &quoted($title)
          . " --separate-output --checklist "
          . &quoted($message)
          . " $height $width $menuheight @list" );
}

sub rhs_checklistl {
    my ( $title, $message, $width, $numitems ) = @_;
    my ( $i, $tmp, $ent, $height, $menuheight, @list, $message_len );

    $width    = int($width);
    $numitems = int($numitems);

    shift;
    shift;
    shift;
    shift;

    @list = ();
    for ( $i = 0 ; $i < $numitems ; $i++ ) {
        $ent         = shift;
        $list[@list] = &quoted($ent);
        $list[@list] = &quoted("");
        $list[@list] = "OFF";
    }

    $message = &rhs_wordwrap( $message, $width );

    $message_len = split( /^/, $message );
    $tmp = $message;
    if ( chop($tmp) eq "\n" ) {
        $message_len++;
    }

    $height = $message_len + 6 + $numitems;
    if ( $height <= $scr_lines ) {
        $menuheight = $numitems;
    }
    else {
        $height     = $scr_lines;
        $menuheight = $scr_lines - $message_len - 6;
    }
    return &return_output( "list",
            "$DIALOG --title "
          . &quoted($title)
          . " --separate-output --checklist "
          . &quoted($message)
          . " $height $width $menuheight @list" );
}

sub rhs_checklista {
    my ( $title, $message, $width, %items ) = @_;
    my ( $tmp, $ent, $height, $menuheight, @list, $message_len );

    shift;
    shift;
    shift;
    shift;

    @list = ();
    foreach $ent ( sort keys(%items) ) {
        $list[@list] = &quoted($ent);
        $list[@list] = &quoted( $items{$ent} );
        $list[@list] = "OFF";
    }

    $message = &rhs_wordwrap( $message, $width );

    $message_len = split( /^/, $message );
    $tmp = $message;
    if ( chop($tmp) eq "\n" ) {
        $message_len++;
    }

    my $numitems = keys(%items);
    $height = $message_len + 6 + $numitems;
    if ( $height <= $scr_lines ) {
        $menuheight = $numitems;
    }
    else {
        $height     = $scr_lines;
        $menuheight = $scr_lines - $message_len - 6;
    }

    return &return_output( "list",
            "$DIALOG --title "
          . &quoted($title)
          . " --separate-output --checklist "
          . &quoted($message)
          . " $height $width $menuheight @list" );
}

sub rhs_radiolist {
    my ( $title, $message, $width, $numitems ) = @_;
    my ( $i, $tmp, $ent, $height, $menuheight, @list, $message_len );

    $width    = int($width);
    $numitems = int($numitems);

    shift;
    shift;
    shift;
    shift;

    @list = ();
    for ( $i = 0 ; $i < $numitems ; $i++ ) {
        $ent         = shift;
        $list[@list] = &quoted($ent);
        $ent         = shift;
        $list[@list] = &quoted($ent);
        $ent         = shift;
        if ($ent) {
            $list[@list] = "ON";
        }
        else {
            $list[@list] = "OFF";
        }
    }

    $message = &rhs_wordwrap( $message, $width );

    $message_len = split( /^/, $message );
    $tmp = $message;
    if ( chop($tmp) eq "\n" ) {
        $message_len++;
    }

    $height = $message_len + 6 + $numitems;
    if ( $height <= $scr_lines ) {
        $menuheight = $numitems;
    }
    else {
        $height     = $scr_lines;
        $menuheight = $scr_lines - $message_len - 6;
    }

    return &return_output( 0,
            "$DIALOG --title "
          . &quoted($title)
          . " --radiolist "
          . &quoted($message)
          . " $height $width $menuheight @list" );
}

sub return_output {
    my ( $listp, $command ) = @_;
    my ($res) = 1;

    pipe( PARENT_READER, CHILD_WRITER );

    # We have to fork (as opposed to using "system") so that the parent
    # process can read from the pipe to avoid deadlock.
    my ($pid) = fork;
    if ( $pid == 0 ) {    # child
        close(PARENT_READER);
        open( STDERR, ">&CHILD_WRITER" );
        exec($command);
        die("no exec");
    }
    if ( $pid > 0 ) {     # parent
        close(CHILD_WRITER);
        if ($listp) {
            @dialog_result = ();
            while (<PARENT_READER>) {
                chop;
                $dialog_result[@dialog_result] = $_;
            }
        }
        else {
            @dialog_result = <PARENT_READER>;
        }
        close(PARENT_READER);
        waitpid( $pid, 0 );
        $res = $?;
    }

    # Again, dialog returns results backwards
    if ( !$res ) {
        return 1;
    }
    else {
        return 0;
    }
}

sub rhs_wordwrap {
    my ( $intext, $width ) = @_;
    my ( $outtext, $i, $j, @lines, $wrap, @words, $pos, $pad );

    $width   = int($width);
    $outtext = "";
    $pad     = 3;             # leave 3 spaces around each line
    $pos     = $pad;          # current insert position
    $wrap    = 0;             # 1 if we have been auto wraping
    my $insert_nl = 0;        # 1 if we just did an absolute
                              # and we should preface any new text
                              # with a new line
    @lines = split( /\n/, $intext );

    for ( $i = 0 ; $i <= $#lines ; $i++ ) {

        if ( $lines[$i] =~ /^>/ ) {
            $outtext .= "\n" if ($insert_nl);
            $outtext .= "\n" if ($wrap);
            $lines[$i] =~ /^>(.*)$/;
            $outtext .= $1;
            $insert_nl = 1;
            $wrap      = 0;
            $pos       = $pad;
        }
        else {
            $wrap = 1;
            @words = split( /\s+/, $lines[$i] );
            for ( $j = 0 ; $j <= $#words ; $j++ ) {
                if ($insert_nl) {
                    $outtext .= "\n";
                    $insert_nl = 0;
                }
                if ( ( length( $words[$j] ) + $pos ) > $width - $pad ) {
                    $outtext .= "\n";
                    $pos = $pad;
                }
                $outtext .= $words[$j] . " ";
                $pos += length( $words[$j] ) + 1;
            }
        }
    }

    return $outtext;
}

############
1;
