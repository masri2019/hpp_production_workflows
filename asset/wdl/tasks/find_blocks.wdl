version 1.0

workflow runFindBlocks{
    call findBlocks
    output {
        File bed = findBlocks.bed
    }
}


task findBlocks {
    input {
        File coverageGz
        File table
        # runtime configurations
        Int memSize=8
        Int threadCount=4
        Int diskSize=128
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

        FILENAME=$(basename ~{coverageGz})
        PREFIX=${FILENAME%.cov.gz}

        gunzip -c ~{coverageGz} > $PREFIX.cov
        ${FIND_BLOCKS_BIN} -c $PREFIX.cov -t ~{table} -p $PREFIX
    >>>
    runtime {
        docker: dockerImage
        memory: memSize + " GB"
        cpu: threadCount
        disks: "local-disk " + diskSize + " SSD"
        preemptible : preemptible
    }
    output {
        File bed = glob("*.bed")[0]
    }
}
