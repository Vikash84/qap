#!/usr/bin/env perl

#################################################################################
##                                                                             ##
##                       Quasispecies Analysis Package                         ##
##                                                                             ##
#################################################################################
##                                                                             ##
##  A software suite designed for virus quasispecies analysis                  ##
##  See our website: <http://bioinfo.rjh.com.cn/labs/jhuang/tools/qap/>        ##
##                                                                             ##
##  Version 1.0                                                                ##
##                                                                             ##
##  Copyright (C) 2017 by Mingjie Wang, All rights reserved.                   ##
##  Contact:  huzai@sjtu.edu.cn                                                ##
##  Organization: Research Laboratory of Clinical Virology, Rui-jin Hospital,  ##
##  Shanghai Jiao Tong University, School of Medicine                          ##
##                                                                             ##
##  This file is a subprogram of QAP suite.                                    ##
##                                                                             ##
##  QAP is a free software; you can redistribute it and/or                     ##
##  modify it under the terms of the GNU General Public License                ##
##  as published by the Free Software Foundation; either version               ##
##  3 of the License, or (at your option) any later version.                   ##
##                                                                             ##
##  QAP is distributed in the hope that it will be useful,                     ##
##  but WITHOUT ANY WARRANTY; without even the implied warranty of             ##
##  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the              ##
##  GNU General Public License for more details.                               ##
##                                                                             ##
##  You should have received a copy of the GNU General Public                  ##
##  License along with QAP; if not, see                                        ##
##  <http://www.gnu.org/licenses/>.                                            ##
##                                                                             ##
#################################################################################

use diagnostics;
use strict;
use warnings;
use FindBin qw/$RealBin/;
use File::Spec;
use Getopt::Long;
use Pod::Usage;
use lib "$FindBin::Bin/../lib";
use Cwd qw/getcwd abs_path/;
use File::Basename;
use List::Util qw/max min/;

####Use modules in this program####
use General;

####Flush cache
$| = 1;

####---------------------------####
####The program begins here
####---------------------------####

##Show welcome
print "You are now running subprogram: ";
printcol ("SingleBaseComplexity","green");
print "\n";

## check threads available or not
sleep(1);
my $threads_usable = eval 'use threads; 1';
if ($threads_usable) {
	use threads;
	use threads::shared;
} else {
	Info("No threading is possible. Please install perl module: threads or recompile perl with option -Dusethreads","red");
}

##get workding directory
my $wk_dir = getcwd;
my $mainBin;
if ($RealBin =~ /(.*)\/bin/){
	$mainBin = $1;
}

####define command line arguments
my $help;
my $inputDir;
my $outputDir;
my $suffix;
my $threads;
my $graphic;

my $DateNow = `date +"%Y%m%d_%Hh%Mm%Ss"`;
chomp $DateNow;

GetOptions(
'i|inputDir|=s'     => \$inputDir,
's|suffix|=s'       => \$suffix,
'o|outputDir|=s'    => \$outputDir,
't|threads|=s'      => \$threads,
'g|graphic|'        => \$graphic,
'h|help|'           => \$help
);


##check command line arguments
if (defined $help){
	pod2usage(-verbose=>2,-exitval=>1);
}

if(scalar(@ARGV) == 0){
	pod2usage(-verbose=>1,-exitval=>1);
}

if (defined $outputDir){
	$outputDir =~ s/\/$//;
	$outputDir = abs_path($outputDir) . "/";
	if (not -e $outputDir){
 		InfoWarn("The output directory $outputDir does NOT exist.",'yellow');
 		InfoWarn("Will mkdir $outputDir and use it as the output directory.",'yellow');
		#pod2usage(-verbose=>0,-exitval=>1);
		#exit;
		if (!-e $outputDir){
			my $cmd = "mkdir -p $outputDir";
			system($cmd);
		}else{
			InfoError("Mkdir Failed! Folder $outputDir already exists!","red");
			InfoError("Please specify another output directory using option -o/--outputDir");
			pod2usage(-verbose=>0,-exitval=>1);
			exit;
		}
	}else{
		InfoError("Output directory $outputDir already exists!","red");
		InfoError("Please specify another folder using option -o/--outputDir");
		pod2usage(-verbose=>0,-exitval=>1);
		exit;
	}
}else{
	$outputDir = File::Spec -> catfile($wk_dir,"qap_Results_for_SingleBaseComplexity_$DateNow");
	InfoWarn("The output directory is not provided!",'yellow');
	InfoWarn("Will mkdir \"$outputDir\" and use it as the output directory.",'yellow');
	
	if (!-e "$outputDir"){
		my $cmd = "mkdir -p $outputDir";
		system($cmd);
	}else{
		InfoError("Mkdir Failed! $outputDir already exists!","red");
		InfoError("Please specify another output directory using option -o/--outputDir\n");
		pod2usage(-verbose=>0,-exitval=>1);
		exit;
	}

}

if(defined $inputDir){
	$inputDir =~ s/\/$//;
	$inputDir = abs_path($inputDir) . "/";
	if (not -e $inputDir){
		InfoError("Input directory $inputDir does NOT exist! Please check again.");
		exit;
	}
}else{
	InfoError("Input directory MUST be specified with -i/--inputDir\n");
	pod2usage(-verbose=>0,-exitval=>1);
	exit;
}

my $numberOfFiles = 0;
my @inputfiles;
if(defined $suffix){
	@inputfiles = glob ("${inputDir}/*.${suffix}");
	
	$numberOfFiles = scalar(@inputfiles);
	
	if ($numberOfFiles == 0){
		InfoError("There are NOT any files in $inputDir with suffix \'.${suffix}\'. Please check again.");
		exit;
	}
	
	Info("Find $numberOfFiles files.");
	my $i = 1;
	for my $f (@inputfiles){
		printf "[%02d] $f\n",$i;
		$i++;
	}
	
}else{
	InfoWarn("The suffix is not provided. The program will try to read in every file in $inputDir");
	
	@inputfiles = glob ("${inputDir}/*.*");
	
	$numberOfFiles = scalar(@inputfiles);
	
	if ($numberOfFiles == 0){
		InfoError("There are NOT any files in $inputDir with suffix \'.${suffix}\'. Please check again.");
		exit;
	}
	
	Info("Find $numberOfFiles files.");
	my $i = 1;
	for my $f (@inputfiles){
		printf "[%02d] $f\n",$i;
		$i++;
	}
	
}

sleep(1);

if (defined $threads){
	my $check_threads_positive = &CheckPositiveInt($threads);
	my $threads_max;
	if(-e ("/proc/cpuinfo")){
		$threads_max = `grep 'processor' /proc/cpuinfo | sort -u | wc -l`;
		chomp $threads_max;
		$threads_max =~ s/\s//g;
	}else{
		my $mac_threads = `sysctl hw.logicalcpu`;
		chomp $mac_threads;
		$mac_threads =~ s/.*\://;
		$mac_threads =~ s/\s//g;
		if($mac_threads >= 2){
			$threads_max = $mac_threads;
		}else{
			$threads_max = 2;
		}
	}

	if ($check_threads_positive && $threads <= $threads_max){
		#threads provided by user is ok, doing nothing
	}else{
		InfoError("Threads number wrong!",'red');
		InfoError("Please provide a threads number between 0 - $threads_max that this server could support.");

		pod2usage(-verbose=>2,-exitval=>1);
		exit;
	}
}else{
	$threads = 1;#if -t not provided, default is NOT use theads;
}

my $visual = 1;
if (defined $graphic){
	#nothing
}else{
	$visual = 0;
}

##core program starts here
#check rscript
my $shannon_rscript = File::Spec -> catfile($mainBin, 'bin', 'Rscripts','CalculateSingleBaseComplexity.R');
my $barplot_rscript = File::Spec -> catfile($mainBin, 'bin', 'Rscripts','Barplot.R');

if (not existFile($shannon_rscript)){
	InfoError("R script $shannon_rscript is missing. Please check.");
	InfoError("Aborting...");
	exit(0);
}

if (not existFile($barplot_rscript)){
	InfoError("R script $barplot_rscript is missing. Please check.");
	InfoError("Aborting...");
	exit(0);
}

#start calculate
if($threads > 1){
	my @outputfiles;
	my @visual;
	my @shannon_rscript;
	my @barplot_rscript;
	
	for my $f (@inputfiles){
		my $outputfile = File::Spec -> catfile($outputDir, removeFastaSuffix(basename($f)) . ".SBC.txt");
		push @outputfiles,$outputfile;
		push @visual, $visual;
		push @shannon_rscript,$shannon_rscript;
		push @barplot_rscript,$barplot_rscript;
	}
	
	Info("Calculating single base complexity using multiple threads.");
	
	runMultipleThreadsWith5Args(\&sbcWithInfo,\@inputfiles,\@outputfiles,\@visual,\@shannon_rscript,\@barplot_rscript,$threads);
	
}else{
	my $i = 1;
	for my $f (@inputfiles){
		my $outputfile = File::Spec -> catfile($outputDir, removeFastaSuffix(basename($f)) . ".SBC.txt");
		
		if(not $visual){
			InfoProcessBar($i, $numberOfFiles);
			&sbc($f,$outputfile,$visual,$shannon_rscript,$barplot_rscript);
		}else{
			&sbcWithInfo($f,$outputfile,$visual,$shannon_rscript,$barplot_rscript);
		}
		
		
		$i++;
	}
}

##sub program starts here
sub sbc { # sbc for single base complexity
	my $inputfile = shift;
	my $outputfile = shift;
	my $visual = shift;
	my $shannon_rscript = shift;
	my $barplot_rscript = shift;
	
	my $inputfileName = basename($inputfile);
	
	#convert to 2 line fasta file
	my $inputfile2Name = removeFastaSuffix(basename($inputfile)) . ".2line.fasta";
	my $inputfile2 = File::Spec -> catfile(dirname($outputfile), $inputfile2Name);
	formatFastaToTwoLineMode($inputfile,$inputfile2);
	
	#r input
	my $rInputName = removeFastaSuffix(basename($inputfile)) . ".RInput";
	my $rInput = File::Spec -> catfile(dirname($outputfile), $rInputName);
	formatFastaForRInput($inputfile2, $rInput);
	
	#run r script
	my $cmd = "Rscript $shannon_rscript -i $rInput -o $outputfile";
	system($cmd);
	
	#visualization
	if ($visual){
		#figure folder
		my $barplotdir = File::Spec -> catfile(dirname($outputfile),'plots');
		my $barplotpdfdir = File::Spec -> catfile($barplotdir, 'pdf');
		my $barplottifdir = File::Spec -> catfile($barplotdir, 'tif');
		
		makedir($barplotdir);
		makedir($barplotpdfdir);
		makedir($barplottifdir);
		
		#draw fig
		$cmd = "Rscript $barplot_rscript -i $outputfile -o $barplotdir -l $inputfileName";
		system($cmd);
	}
	
	#remove tmp file
	system("rm -rf $inputfile2");
	system("rm -rf $rInput");
}

sub sbcWithInfo { # sbc for single base complexity
	my $inputfile = shift;
	my $outputfile = shift;
	my $visual = shift;
	my $shannon_rscript = shift;
	my $barplot_rscript = shift;
		
	my $inputfileName = basename($inputfile);
	Info("Calculating single base shannon entroy for $inputfileName");
	
	#convert to 2 line fasta file
	my $inputfile2Name = removeFastaSuffix(basename($inputfile)) . ".2line.fasta";
	my $inputfile2 = File::Spec -> catfile(dirname($outputfile), $inputfile2Name);
	formatFastaToTwoLineMode($inputfile,$inputfile2);
	
	#r input
	my $rInputName = removeFastaSuffix(basename($inputfile)) . ".RInput";
	my $rInput = File::Spec -> catfile(dirname($outputfile), $rInputName);
	formatFastaForRInput($inputfile2, $rInput);
	
	#run r script
	my $cmd = "Rscript $shannon_rscript -i $rInput -o $outputfile";
	runcmd($cmd);
	
	#visualization
	if ($visual){
		#figure folder
		my $barplotdir = File::Spec -> catfile(dirname($outputfile),'plots');
		my $barplotpdfdir = File::Spec -> catfile($barplotdir, 'pdf');
		my $barplottifdir = File::Spec -> catfile($barplotdir, 'tif');
		
		makedir($barplotdir);
		makedir($barplotpdfdir);
		makedir($barplottifdir);
		
		#draw fig
		$cmd = "Rscript $barplot_rscript -i $outputfile -o $barplotdir -l $inputfileName";
		runcmd($cmd);
	}
	
	#remove tmp file
	system("rm -rf $inputfile2");
	system("rm -rf $rInput");
	
}

##run success
print("\n\n");
Info("Program completed!",'green');


####---------------------------####
####The program ends here
####---------------------------####


=pod 

=head1 NAME

qap -- Quasispecies analysis package

=head1 SYNOPSIS


       ______       ______       ______
      / ___  |     / ____ \     |  ___ \
     / /   | |    / |    | |    | |   \ \
    | |    | |    | |    |_|    | |    | |
     \ \___| |    \ |____\ \    | |___/ /
      \____  |     \_____/\_\   | |____/
           | |                  | |
           | |                  | |
           | |                  | |
           |_|                  |_|         v1.0
           



qap SingleBaseComplexity [options]

Use --help to see more information.

qap is still in development. If you have encounted any problem in usage, please feel no hesitation to cotact us.

=head1 DESCRIPTION

This script implements a function for cutting fasta sequences with base intervals in batch. The script has B<several> mandatory options that MUST appear last. 

=head1 OPTIONS

=over 5

=item --inputDir,-i F<FILE> [Required]

Path to directory contaning all the files to be read in.

=item --suffix,-s F<STRING> [Optional]

Suffix of the files to be read in. If suffix is not provided, all the files in input directory will be read in.

=item --outputDir,-o F<FILE> [Optional]

Path of the directory to storage result files. If NOT provided, the program will generate a folder automatically.

=item --graphic,-g 

Whether to visualize the result of single base complexity of input files.

=item --threads,-t F<INTEGER> [Optional]

Number of threads this program will use when computing. A positive integer should be provided. The default value is 1.

=item --help,-h

Display this detailed help information.

=back

=head1 EXAMPLE

=over 5

qap SingleBaseComplexity -i ./seq -t 10 -s fasta -l 100 -e 20 -o ./cutTile

=back

=head1 AUTHOR

Mingjie Dr.Wang I<huzai@sjtu.edu.cn>

=head1 COPYRIGHT

Copyright (C) 2017, Mingjie Wang. All rights reserved.
