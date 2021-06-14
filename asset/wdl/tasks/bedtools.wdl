version 1.0

## This wdl contains the 3 operations frequently used for bed files; subtract, intersect, union

task subtract {
    input {
        File firstBed
        File secondBed
        String outputPrefix = "subtract"
        # runtime configurations
        Int memSize=4
        Int threadCount=2
        Int diskSize=32
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

        mkdir output
        bedtools subtract -a ~{firstBed} -b ~{secondBed} | bedtools sort -i - | bedtools merge -i - > output/~{outputPrefix}.bed

    >>>
    runtime {
        docker: dockerImage 
        memory: memSize + " GB"
        cpu: threadCount
        disks: "local-disk " + diskSize + " SSD"
    }
    output {
        File subtractBed = glob("output/*.bed")[0]
    }
}

task intersect {
    input {
        Array[File] bedFiles
        String outputPrefix = "intersect"
        # runtime configurations
        Int memSize=4
        Int threadCount=2
        Int diskSize=32
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

        mkdir output
        multiIntersectBed -i ~{sep=" " bedFiles} | bedtools sort -i - | bedtools merge -i - > output/~{outputPrefix}.bed

    >>>
    runtime {
        docker: dockerImage
        memory: memSize + " GB"
        cpu: threadCount
        disks: "local-disk " + diskSize + " SSD"
    }
    output {
        File intersectBed = glob("output/*.bed")[0]
    }
}

task union {
    input {
        Array[File] bedFiles
        String outputPrefix = "union"
        # runtime configurations
        Int memSize=4
        Int threadCount=2
        Int diskSize=32
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

        mkdir output
        cat ~{sep=" " bedFiles} | bedtools sort -i - | bedtools merge -i - > output/~{outputPrefix}.bed

    >>>
    runtime {
        docker: dockerImage
        memory: memSize + " GB"
        cpu: threadCount
        disks: "local-disk " + diskSize + " SSD"
        preemptible : preemptible
    }
    output {
        File unionBed =  glob("output/*.bed")[0]
    }
}
