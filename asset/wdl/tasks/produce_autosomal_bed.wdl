version 1.0

import "bedtools.wdl" as bedtools_t

workflow produceAutosomalBed {
    input {
        File nonCntr_nonSex_nonMito_bed
        File chrX_PAR_bed
        File chrY_PAR_bed
    }
    call bedtools_t.union {
       input:
          bedFiles = [nonCntr_nonSex_nonMito_bed, chrX_PAR_bed, chrY_PAR_bed] 
    }
    output {
       File autosomal_nonCntr_bed = union.unionBed
    }
}
