#!/bin/sh
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
# Top level LM text processing script. Set $TEXTTOP accordingly, and then
# run with ./Resources/bin/PrepLmData.sh after copying the LDC verbalized
# punctuation data to $TEXTTOP/Resources/LDC/vp_train/bn*Z

TEXTTOP=`pwd`
TEXTBIN=$TEXTTOP/Resources/bin
LMDATADIR=$TEXTTOP/Resources/LDC/vp_train

if [ ! -x $TEXTBIN/ParseLMVP.py -o ! -x $TEXTBIN/TextNormLMVP.pl ]; then
  echo "Cannot find SGML parser or text normalizer for BN LMVP"
  exit 1
fi

if [ ! -d $LMDATADIR ]; then
  echo "Cannot find BN LM resource dir $LMDATADIR"
  exit 1
fi

echo "   Parsing and normalizing BN LM training text"
gzip -dc $LMDATADIR/bn*Z | \
    $TEXTBIN/ParseLMVP.py | \
    $TEXTBIN/TextNormLMVP.pl | \
    gzip > $TEXTTOP/bnlm.txt.gz

echo "   Computing training/test partition used in Interspeech 2010 paper"
gzip -dc $TEXTTOP/bnlm.txt.gz | head -8500000 > $TEXTTOP/BN-lm-text.train
gzip -dc $TEXTTOP/bnlm.txt.gz | tail -45867   > $TEXTTOP/BN-lm-text.test
rm -rf $TEXTTOP/bnlm.txt.gz
