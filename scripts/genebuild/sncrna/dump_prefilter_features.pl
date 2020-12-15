use strict;
use warnings;

use File::Spec::Functions qw(catfile);
use Bio::EnsEMBL::DBSQL::DBAdaptor;

my ($dbname, $dbhost, $dbport, $dbuser, $working_dir, $logic_name) = @ARGV;

my $db = Bio::EnsEMBL::DBSQL::DBAdaptor->new(
	-DBNAME => $dbname,
  	-HOST => $dbhost,
  	-PORT => $dbport,
  	-USER => $dbuser,
	-DRIVER => 'mysql',
);

my $daf_adaptor = $db->get_DnaAlignFeatureAdaptor();

my $fn = catfile($working_dir, $logic_name.'_dafs.bed');

open(FH, '>', $fn) or die "Could not write to $fn";

foreach my $daf (@{$daf_adaptor->fetch_all_by_logic_name($logic_name)}) {
	my $strand = $daf->strand() > 0 ? "+" : "-";


	print FH $daf->seq_region_name(), "\t",
		$daf->seq_region_start(), "\t",
		$daf->seq_region_end(), "\t",
		$daf->seq_region_name(), ":",
		$daf->seq_region_start(), "-",
		$daf->seq_region_end(), "\t",
		$daf->score(), "\t",
		$strand, "\t",
		$daf->hseqname(), "\t",
		$daf->p_value(), "\t",
		$daf->percent_id(), "\t",
		$daf->cigar_string(),  "\n";

}

close(FH) or die("Could not close $fn");

# dump putative stem-loops
my $gene_adaptor = $db->get_GeneAdaptor();

$fn = catfile($working_dir, 'identified_mirnas.bed');

open(FH, '>', $fn) or die "Could not write to $fn";

foreach my $gene (@{$gene_adaptor->fetch_all_by_biotype('miRNA')}){
    my $strand = $gene->strand() > 0 ? "+" : "-";


      print FH $gene->seq_region_name(), "\t",
          $gene->seq_region_start(), "\t",
          $gene->seq_region_end(), "\t",
          $gene->seq_region_name(), ":",
          $gene->seq_region_start(), "-",
          $gene->seq_region_end(), "\t0\t",
          $strand, "\t",
          $gene->dbID(), "\n";

}

close(FH) or die("Could not close $fn");

