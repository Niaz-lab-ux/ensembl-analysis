# Ensembl module for Bio::EnsEMBL::Analysis::Tools::FilterBPlite
#
# Copyright (c) 2004 Ensembl
#

=head1 NAME

  Bio::EnsEMBL::Analysis::Tools::FilterBPlite

=head1 SYNOPSIS

  my $parser = Bio::EnsEMBL::Analysis::Tools::FilterBPlite->
  new(
      -regex => '^\w+\s+(\w+)'
      -query_type => 'dna',
      -database_type => 'pep',
      -threshold_type => 'PVALUE',
      -threshold => 0.01,
     );
 my @results = @{$parser->parse_results('blast.out')};

=head1 DESCRIPTION

This module inherits from BPliteWrapper so follows the same basic 
methodology but it implements some prefiltering of the HSPs to mimic how
the old pipeline blast runnable was used in the raw computes

=head1 CONTACT

Post questions to the Ensembl development list: ensembl-dev@ebi.ac.uk

=cut

package Bio::EnsEMBL::Analysis::Tools::FilterBPlite;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Exception qw(verbose throw warning);
use Bio::EnsEMBL::Utils::Argument qw( rearrange );
use Bio::EnsEMBL::Analysis::Tools::BPliteWrapper;
use Bio::EnsEMBL::Analysis::Tools::FeatureFilter;
use vars qw (@ISA);

@ISA = qw(Bio::EnsEMBL::Analysis::Tools::BPliteWrapper);


=head2 new

  Arg [1]   : Bio::EnsEMBL::Analysis::Tools::FilterBPlite
  Arg [THRESHOLD_TYPE] : string, threshold type
  Arg [THRESHOLD] : int, threshold
  Arg [COVERAGE] : int, coverage value
  Arg [FILTER] : int, boolean toggle as whether to filter
  Function  : create a Bio::EnsEMBL::Analysis::Tools::FilterBPlite
  object
  Returntype: Bio::EnsEMBL::Analysis::Tools::FilterBPlite
  Exceptions: 
  Example   : 

=cut


sub new{
  my ($class,@args) = @_;
  my $self = $class->SUPER::new(@args);
  &verbose('WARNING');
  my ($threshold_type, $threshold, $coverage, $filter) = rearrange
    (['THRESHOLD_TYPE', 'THRESHOLD', 'COVERAGE', 'FILTER'], @args);
  ######################
  #SETTING THE DEFAULTS#
  ######################
  $self->coverage(10);
  $self->filter(1);
  ######################

  $self->threshold_type($threshold_type);
  $self->threshold($threshold);
  $self->coverage($coverage) if(defined($coverage));
  $self->filter($filter) if(defined($filter));
  return $self;
}


=head2 Container method

  Arg [1]   : Bio::EnsEMBL::Analysis::Tools::FilterBPlite
  Arg [2]   : string/int
  Function  : container methods, this documents the 4 methods
  below threshold_type, threshold, coverage, filter
  Returntype: string/int
  Exceptions: 
  Example   : 

=cut


sub threshold_type{
  my $self = shift;
  $self->{'threshold_type'} = shift if(@_);
  return $self->{'threshold_type'};
}

sub threshold{
  my $self = shift;
  $self->{'threshold'} = shift if(@_);
  return $self->{'threshold'};
}

sub coverage{
  my $self = shift;
  $self->{'coverage'} = shift if(@_);
  return $self->{'coverage'};
}

sub filter{
  my $self = shift;
  $self->{'filter'} = shift if(@_);
  return $self->{'filter'};
}



=head2 get_hsps

  Arg [1]   : Bio::EnsEMBL::Analysis::Tools::FilterBPlite
  Arg [2]   : Bio::EnsEMBL::Analysis::Tools::BPlite
  Function  : prefilter the hsps then parser then and turn them into
  features
  Returntype: none 
  Exceptions: throw if no name can be parser from the subject
  Example   : 

=cut



sub get_hsps{
  my ($self, $parsers) = @_;
  my $regex = $self->regex;
  my @output;
  my $ids;
  if($self->filter){
    $ids = $self->filter_hits($parsers);
  }
  my $seconds = $self->get_parsers($self->filenames);
 PARSER:foreach my $second(@$seconds){
  NAME: while(my $sbjct = $second->nextSbjct){
      if($self->filter && !($ids->{$sbjct->name})){
        next NAME;
      }
      my ($name) = $sbjct->name =~ /$regex/;
      throw("Error parsing name from ".$sbjct->name." check your ".
            "blast setup and blast headers") unless($name);
    HSP: while (my $hsp = $sbjct->nextHSP) {
        if($self->is_hsp_valid($hsp)){     
          push(@output, $self->split_hsp($hsp, $name));
        }
      }
    }
  }
  $parsers = [];
  $self->output(\@output);
}



=head2 filter_hits

  Arg [1]   : Bio::EnsEMBL::Analysis::Tools::FilterBPlite
  Arg [2]   : Bio::EnsEMBL::Analysis::Tools::BPlite
  Function  : prefilter the blast results using specified thresholds
  and FeatureFilter
  Returntype: hashref
  Exceptions: 
  Example   : 

=cut



sub filter_hits{
  my ($self, $parsers) = @_;
  my %ids;
  my @features;
  my $sc = 0;
  my $hspc = 0;
  my $skipped = 0;
 PARSER:foreach my $parser(@$parsers){
  SUB:while(my $sbjct = $parser->nextSbjct){
      $sc++;
      my $name = $sbjct->name;
    HSP:while (my $hsp = $sbjct->nextHSP) {
        $hspc++;
        if($self->is_hsp_valid($hsp)){
          my $qstart = $hsp->query->start();
          my $hstart = $hsp->subject->start();
          my $qend   = $hsp->query->end();
          my $hend   = $hsp->subject->end();
          my $qstrand = $hsp->query->strand();
          my $hstrand = $hsp->subject->strand();
          my $score  = $hsp->score;
          my $p_value = $hsp->P;
          my $percent = $hsp->percent;
          
          my $fp = $self->feature_factory->create_feature_pair
            ($qstart, $qend, $qstrand, $score, $hstart,
             $hend, $hstrand, $name, $percent, $p_value);
          
          push(@features,$fp);
        }else{
          $skipped++;
        }
      }
    }
  }
  print "There were ".$sc." subjects\n";
  print "There were ".$hspc." hsps\n";
  print $skipped." hsps were skipped\n";
  print "There are ".@features."before feature filter\n";
  my $search = Bio::EnsEMBL::Analysis::Tools::FeatureFilter->new
    (
     -coverage => $self->coverage,
    );
  my @newfeatures = @{$search->filter_results(\@features)};
  print "There were ".@newfeatures." after feature filter\n";
  foreach my $f (@newfeatures) {
    my $id = $f->hseqname;
    $ids{$id} = 1;
  }
  return \%ids;
}



=head2 is_hsp_valid

  Arg [1]   : Bio::EnsEMBL::Analysis::Tools::FilterBPlite
  Arg [2]   : Bio::EnsEMBL::Analysis::Tools::BPlite::HSP
  Function  : checks hsp against specified threshold returns hsp
  if above value 0 if not
  Returntype: Bio::EnsEMBL::Analysis::Tools::BPlite::HSP/0
  Exceptions: 
  Example   : 

=cut



sub is_hsp_valid{
  my ($self, $hsp) = @_;
  if($self->threshold_type){
    if ($self->threshold_type eq "PID") {
      return 0 if ($hsp->percent < $self->threshold);
    } elsif ($self->threshold_type eq "SCORE") {
      return 0 if ($hsp->score < $self->threshold);
    } elsif ($self->threshold_type eq "PVALUE") {
      return 0 if($hsp->P > $self->threshold);
    } 
  }
  return $hsp;
}
