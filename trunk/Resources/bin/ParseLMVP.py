#!/usr/bin/python -O
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
# Parser for the LM text data. Reads the SGML formatted LM text data
# from stdin and writes the text to stdout.
#

import sys
from sgmllib import SGMLParser

########################################################################
class BNLMVPParser(SGMLParser):
  """Convert HUB4_LM SGML (the VP, or Verbalized Punctuation, version)
  to plain text format.

  Recognizes the following tags:
  art : article
  p   : paragraph
  s   : sentence

  Uses only sentece tagging. <art> and <p> are pretty much ignored.
  Outputs text one sentence per line.
  """

  def __init__(self):
    SGMLParser.__init__(self)

    self.in_paragraph = False
    self.text = ""

  def Parse(self):
    """Parse the given string"""
    for line in sys.stdin:
      self.feed(line)

  def output(self):
    s = ' '.join(self.text.split())
    if len(s) > 0:  print s
    self.text = ''

  def start_p(self, attrs):
    self.in_paragraph = True

  def end_p(self):
    self.output()
    self.in_paragraph = False

  def do_s(self, attrs):
    assert self.in_paragraph

    # end previous sentence
    self.output()

  def handle_data(self, data):
    self.text += data

  def start_art(self, attributes):
    pass

  def end_art(self):
    pass

  def unknown_starttag(self, tag, attributes):
    raise NameError, 'start->' + tag

  def unknown_endtag(self, tag, attributes):
    raise NameError, 'end->' + tag



########################################################################
parser = BNLMVPParser()
try:
  parser.Parse()
except NameError, e:
  print >> sys.stderr, 'Found unknown tag: %s' % str(e)
  sys.exit(1)
