package Slim::Utils::SoundCheck;

# $Id$
# 
# SlimServer Copyright (c) 2001-2006 Slim Devices Inc.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License, 
# version 2.
#
# Convert iTunes SoundCheck values to dB. See the POD at the end of the file.
# 
# Thanks to Manfred Schwind for the deciphering.

use strict;
use List::Util qw(max);
use POSIX qw(log10 pow);

sub commentTagTodB {
	my $tags = shift;

	if (ref($tags) ne 'HASH' || !$tags->{'COMMENT'}) {
		return;
	}

	# Normalize all comments to array refs
	if (!ref($tags->{'COMMENT'})) {

		$tags->{'COMMENT'} = [ $tags->{'COMMENT'} ];
	}

	# Look for the iTunNORM tag. If this is the only comment we
	# have, don't pass it along.
	for (my $i = 0; $i < scalar @{$tags->{'COMMENT'}}; $i++) {

		my $comment = $tags->{'COMMENT'}->[$i];

		if ($comment =~ /^iTunNORM/) {

			$tags->{'REPLAYGAIN_TRACK_GAIN'} = normStringTodB($comment);

			splice(@{$tags->{'COMMENT'}}, $i, 1);
		}
	}

	if (!scalar @{$tags->{'COMMENT'}}) {
		delete $tags->{'COMMENT'};
	}
}

sub normStringTodB {
	my $tag    = shift;

	$tag =~ s/^iTunNORM:?\s*//;
	$tag =~ s/^\s*//g;
	$tag =~ s/\s*$//g;

	# Bug: 4346 - can't parse empty strings.
	if (!$tag) {
		return;
	}

	my @values = map { oct(sprintf('0x%s', $_)) } split(/\s+/, $tag);

	return sprintf('%.2f dB', normValueToDBChange(maxNormValue(@values), 1000));
}

sub dBChangeToNormValue {
	my ($dBChange, $base) = @_;

        my $result = _round(pow(10, -$dBChange / 10) * $base);

        if ($result > 65534) {
                $result = 65534;
        }

        return $result;
}

sub normValueToDBChange {
	my ($normValue, $base) = @_;

        return -log10($normValue / $base) * 10;
}

sub maxNormValue {
	my @values = @_;

        my $max1 = max(@values[0..1]);
        my $max2 = max(@values[2..3]);

	# Norm max2 to the same base as max1
           $max2 = dBChangeToNormValue(normValueToDBChange($max2, 2500), 1000);

        return max($max1, $max2);
}

sub _round {
	my $number = shift;

	return int($number + .5 * ($number <=> 0));
}

1;

__END__

=head1 NAME

Slim::Utils::SoundCheck

=head1 SYNOPSIS

use Slim::Utils::SoundCheck;

my $dB = Slim::Utils::SoundCheck::normStringTodB($iTunNORM);

=head1 DESCRIPTION

The iTunNORM tag consists of 5 value pairs. These 10 values are encoded as
ASCII Hex values of 8 characters each inside the tag (plus a space as prefix).
 
The tag can be found in MP3, AIFF, AAC and Apple Lossless files.

The relevant information is what is encoded in these 5 value pairs. The first
value of each pair is for the left audio channel, the second value of each
pair is for the right channel.

0/1: Volume adjustment in milliWatt/dBm

2/3: Same as 0/1, but not based on 1/1000 Watt but 1/2500 Watt

4/5: Not sure, but always the same values for songs that only differs in volume - so maybe some statistical values.

6/7: The peak value (maximum sample) as absolute (positive) value; therefore up to 32768 (for songs using 16-Bit samples).

8/9: Not sure, same as for 4/5: same values for songs that only differs in volume.

iTunes is choosing the maximum value of the both first pairs (of the first 4 values) to adjust the whole song.

=head1 METHODS

=head2 B<commentTagTodB( tags )>

=over

Takes a hash ref with a COMMENT tag and adds a gain value to the hash.

=back

=head2 B<normStringTodB( iTunNORMString )>

=over

Transform an iTunNORM string in the format of:

000001FB 000001C4 0000436C 00003A09 00024CA8 00024CA8 00007FFF 00007FFF 00024CA8 00024CA8

into a dB value. Any leading spaces in the string are stripped.

=back

=head2 B<dBChangeToNormValue( dbChange, base )>

=over

Transform dB change to iTunNORM value:

Base is 1000 (first iTunNORM pair) or 2500 (second iTunNORM pair)

=back

=head2 B<normValueToDBChange( normValue, base>

=over

Transform iTunNORM value to dB change:

Base is 1000 (first iTunNORM pair) or 2500 (second iTunNORM pair)

=back

=head2 B<maxNormValue( values )>

=over

In: first 4 iTunNORM values, Out: maximum value normed to base 1000.

=back

=head1 SEE ALSO

L<Slim::Formats::MP3>, L<Slim::Formats::Movie>, L<Slim::Formats::AIFF>, iTunes

=cut
