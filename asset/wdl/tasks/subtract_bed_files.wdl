version 1.0

import "bedtools.wdl" as bedtools_t

workflow unionBedFiles {
    call bedtools_t.subtract
    output {
       File subtractBed = subtract.subtractBed
    }
}
