#!/usr/bin/perl
#
# Copyright 2010 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Text normalization for BN LM text ("verbalized punctuation" version).
# Perl, rather than Python, is used here for faster regular expression
# operations.
#
#  Find single letter sequences and connect them to form acronyms, e.g.
#    O. J.      -> o_j_
#    A. B. C.   -> a_b_c_
#    C. N. N.'s -> c_n_n_'s
#
#  Map single letters, e.g.:
#    F.         -> f_
#
#  Remove verbalized punctuations, e.g.:
#    ,COMMA
#    .PERIOD
#    ?QUESTION-MARK
#    'SINGLE-QUOTE
#
#  Remove word fragments, e.g.:
#    I-
#
#  Remove leading "-":
#    -the       -> the
#
#  Map Filled pause words to %um and %uh.
#    um|hm|umm|hmm|...     -> %um
#    ah|eh|uh|ahh|uhh|...  -> %uh
#
#  Some special mappings:
#    Mr.      -> mister
#    Ms.      -> miss
#    Mrs.     -> missus
#    O. K.    -> okay
#    E.-mail  -> email
#
#  Remove trailing "."
#
#  Break spelling sequences, adding missing "." for A/I:
#    G.-I-G.-S. -> g_ i_ g_ s_
#    H.-A-I-L.  -> h_ a_ i_ l_
#  Note: T.-shirt now becomes t_-shirt, K.-mart becomes k_-mart, etc.
#


while (<>) {
  # Capitalization in the data is somewhat consistent and makes
  # processing easier. We lower-case the sentence at the very end.

  ##################################################################
  # connect sequence of single letter words to form acronyms

  s/(\b\w)\.\s*(?=\w\.)/\1_/g;
  # take care of the final letter in a sequence, as well as
  # single letter words, single letters in spellings (e.g. p.-t.)
  s/(^|\s|_|\-)(\w)\./\1\2_/g;

  ##################################################################
  # word level processing

  @nwords = ();
  foreach (split) {
    # remove VPs
    next if (/^[^\w]+[A-Z\-]+$/);
    # remove garbage
    next unless (/\w/);

    # use lower-case for pattern matching, but keep capitalized version
    # around for special cases
    $w = $_;
    $_ = lc;

    if (/\-$/) {
      # remove word fragments
    } elsif (/^\-/) {
      s/^\-//;
      push @nwords, $_;
    } elsif (/^(um+|hm+)$/) {
      push @nwords, "%um";
    } elsif (/^(ah+|eh+|uh+)$/) {
      push @nwords, "%uh";
    } elsif (/^e_\-mail$/) {
      push @nwords, "email";
    } elsif (/^mr\.$/) {
      push @nwords, "mister";
    } elsif (/^ms\.$/) {
      push @nwords, "miss";
    } elsif (/^mrs\.$/) {
      push @nwords, "missus";
    } elsif (/^o_k_$/) {
      push @nwords, "okay";
    } elsif (/\.$/) {
      # remove trailing '.', which exists mostly before 'SINGLE-QUOTE
      s/\.$//;
      push @nwords, $_;
    } elsif (/_\-/) {
      # potentially  r_-a-p.-t
      if (/[a-z][a-z]/) {
	push @nwords, $_;
      } else {
	$_ = $w;

	# remove "-"
	s/\-/ /g;
	# adding missing "_" to A/I in a spelling sequence
	s/([AI])\b/\1_/g;
	push @nwords, $_;
      }
    } else {
      push @nwords, $_;
    }
  }

  if (@nwords > 0) {
    $s = lc(join(" ", @nwords));
    # replace all left-over hyphenation with white space
    $s =~ s/-/ /g;
    print "$s\n";
  }
}
