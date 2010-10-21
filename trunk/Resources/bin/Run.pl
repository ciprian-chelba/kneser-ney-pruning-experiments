#!/usr/bin/perl -w
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
# Estimates a bunch of LMs, prunes them aggressively to roughly same size and compares PPLs

use strict;
use Getopt::Long;

# set these as needed
my $srilm_bin = "path-to-dir/SRILM/sri/bin/i686";
my $package_dir = "path-to-dir/kneser_ney_pruning_experiments";

my $ngram = "$srilm_bin/ngram";
my $ngramcount = "$srilm_bin/ngram-count";
my $order = 4;
my $target_lm_size = 400000;
my $models="";  # comma separated list of models to run, e.g. --models="GoodTuring,KneserNey"
my $ret = Getopt::Long::GetOptions("order=i"                  => \$order,
				   "target_lm_size=i"         => \$target_lm_size,
				   "models=s"                 => \$models);
chomp $models;
$models = ",$models,";
print STDERR "Experiment: order=$order target_lm_size=$target_lm_size\n";

my $output_dir = "$package_dir/${order}gram";
if (-d $output_dir) {
  ;  # `rm -rf $output_dir/*`;
} else {
  `mkdir $output_dir`;
}

my $vocab = "$package_dir/BN-lm-text.vocab";
my $training_set = "$package_dir/BN-lm-text.train";
my $test_set = "$package_dir/BN-lm-text.test";
my $common_flags = "-order $order -vocab $vocab -unk -text $training_set";
my $common_pruning_flags = "-unk -order $order -renorm";
my $common_ppl_flags = "-unk -order $order";

my %flags = ("GoodTuring" => "",
	     "Ney" => "-cdiscount 0.8",
	     "NeyInterpolated" => "-cdiscount -interpolate",
	     "WittenBell" => "-wbdiscount",
	     "WittenBellInterpolated" => "-wbdiscount -interpolate",
	     "Ristad" => "-ndiscount",
	     "KneserNey" => "-ukndiscount",
	     "KneserNeyInterpolated" => "-ukndiscount -interpolate",
	     "KneserNeyalaChenGoodman" => "-kndiscount",
	     "KneserNeyalaChenGoodmanInterpolated" => "-kndiscount -interpolate"
	    );

my %threshold = ("GoodTuring" => 1.2e-6,
		 "Ney" => 1.1e-6,
		 "NeyInterpolated" => 1.2e-6,
		 "WittenBell" => 0.9e-6,
		 "WittenBellInterpolated" => 1.3e-6,
		 "Ristad" => 1.7e-6,
		 "KneserNey" => 1.5e-6,
		 "KneserNeyInterpolated" => 1.7e-6,
		 "KneserNeyalaChenGoodman" => 1.2e-06,
		 "KneserNeyalaChenGoodmanInterpolated" => 1.7e-06
		);

# vocabulary
if (-e $vocab) {
  print STDERR "Using existing vocabulary $vocab\n";
} else {
  `$ngramcount -text $training_set -write-order 1 -write $package_dir/BN-lm-text.train.1cnt`;
  `awk '\$2>1' $package_dir/BN-lm-text.train.1cnt | cut -f1 | sort > $vocab`;
}

# models
my $model = "";
foreach $model (keys %flags) {
  # if model list is specified, check that model is part of list of models.
  if ( (length($models) > 2) && (index($models, ",$model,") == $[-1) ) {
    next;
  }
  print STDERR "Estimating model $model...\t";
  if ((-e "$output_dir/${model}.gz") && (-e "$output_dir/log.$model.ppl")) {
    print STDERR "Model $output_dir/${model}.gz exists.\t";
  } else {
    `$ngramcount $common_flags $flags{$model} -lm $output_dir/${model}.gz > $output_dir/log.$model 2>&1`;
    `$ngram $common_ppl_flags -lm $output_dir/${model}.gz -ppl $test_set > $output_dir/log.$model.ppl 2>&1`;
  }
  print STDERR "Done!\n";
  my $unpruned_ppl = `grep ppl $output_dir/log.$model.ppl`;
  chomp $unpruned_ppl;
  $unpruned_ppl =~ s/^.*ppl\= (\S+).*$/$1/;
  my $unpruned_size = lm_size("$output_dir/${model}.gz");

  print STDERR "Pruning model $model...\t";
  my $size = 0;
  while (1) {
    print STDERR "thresh=$threshold{$model}";
    `$ngram $common_pruning_flags -lm $output_dir/${model}.gz -prune $threshold{$model} -write-lm $output_dir/${model}.pruned.gz > $output_dir/log.$model.pruned 2>&1`;
    $size = lm_size("$output_dir/${model}.pruned.gz");
    print STDERR "($size)\t";
    if ($size <= $target_lm_size) {
      `$ngram $common_ppl_flags -lm $output_dir/${model}.pruned.gz -ppl $test_set > $output_dir/log.$model.pruned.ppl 2>&1`;
      print STDERR "Done!\n";
      last;
    } else {
      $threshold{$model} += 1e-7;
    }
  }

  my $pruned_ppl = `grep ppl $output_dir/log.$model.pruned.ppl`;
  chomp $pruned_ppl;
  $pruned_ppl =~ s/^.*ppl\= (\S+).*$/$1/;

  print "$model\tun/pruned_ppl=$unpruned_ppl/$pruned_ppl\tun/pruned_size=$unpruned_size/$size\t\n";
}

# calculate n-gram model size
sub lm_size {
  my ($lm) = @_;
  my $header=`zcat $lm | head`;
  $header =~ s/^\s*\\data\\\s+//;
  $header =~ s/\n/\t/g;
  $header =~ s/\\1\-grams.*//;
  chomp $header;
  $header =~ s/ngram \d\=//g;
  my @counts = split(" ", $header);
  my $total = 0;
  while ($#counts>=0){
    $total += shift(@counts);
  }
  return $total;
}
