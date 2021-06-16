version 1.0

workflow runFillGapsMale {
    input {
        File fai
        File autosome_nonCntr_bed
        File sex_nonCntr_bed
        File autosome_cntr_bed
        File sex_cntr_bed 
    }
    call fillGaps {
        input:
            fai = fai,
            bedFiles = [autosome_nonCntr_bed, sex_nonCntr_bed, autosome_cntr_bed, sex_cntr_bed]
    }
    output {
       File autosome_nonCntr_filled_bed = fillGaps.filledBedFiles[0]
       File sex_nonCntr_filled_bed = fillGaps.filledBedFiles[1]
       File autosome_cntr_filled_bed = fillGaps.filledBedFiles[2]
       File sex_cntr_filled_bed = fillGaps.filledBedFiles[3]
    }
}

task fillGaps {
    input {
        File fai
        Array[File] bedFiles
        # runtime configurations
        Int memSize=4
        Int threadCount=2
        Int diskSize=16
        String dockerImage="quay.io/masri2019/hpp_asset:latest"
        Int preemptible=2
    }
    command <<<
        # Set the exit code of a pipeline to that of the rightmost command
        # to exit with a non-zero status, or zero if all commands of the pipeline exit
        set -o pipefail
        # cause a bash script to exit immediately when a command fails
        set -e
        # cause the bash shell to treat unset variables as an error and exit immediately
        set -u
        # echo each line of the script to stdout so we can see what is happening
        # to turn off echo do 'set +o xtrace'
        set -o xtrace
        
        # find and assign gaps (will produce bed files with the suffix "gaps.bed")
        python3 ${ASSIGN_GAPS_PY} --fai ~{fai} ~{sep=" " bedFiles}
        
        
        for IN_BED in ~{sep=" " bedFiles}
        do
            PREFIX=$(basename ${IN_BED%.bed})
            cat ${IN_BED} ${PREFIX}.gaps.bed | bedtools sort -i - | bedtools merge -i - > ${PREFIX}.filled_gaps.bed
            printf "${PREFIX}.filled_gaps.bed " >> output_list.txt
        done
    >>> 
    runtime {
        docker: dockerImage
        memory: memSize + " GB"
        cpu: threadCount
        disks: "local-disk " + diskSize + " SSD"
        preemptible : preemptible
    }
    
    output {
        Array[File] filledBedFiles = glob(read_string("output_list.txt"))
    }
}

