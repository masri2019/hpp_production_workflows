version 1.0

import "fill_gaps_male.wdl" as fillGaps_t

workflow runFillGapsFemale {
    input {
        File fai
        File autosome_nonCntr_bed
        File autosome_cntr_bed 
    }
    call fillGaps_t.fillGaps {
        input:
            fai = fai,
            bedFiles = [autosome_nonCntr_bed, autosome_cntr_bed]
    }
    output {
       File autosome_nonCntr_filled_bed = fillGaps.filledBedFiles[0]
       File autosome_cntr_filled_bed = fillGaps.filledBedFiles[1]
    }
}
