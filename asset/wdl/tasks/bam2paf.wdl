version 1.0

workflow runBam2Paf{
    call bam2paf    
}
task bam2paf{
    input{
        File bamFile
        Int minMAPQ
        String primaryOnly = "no"
        # runtime configurations
        Int memSize=16
        Int threadCount=4
        Int diskSize=256
        String dockerImage="quay.io/masri2019/hpp_long_read_aligner:latest"
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

        # Convert bam to paf using https://github.com/lh3/minimap2/blob/master/misc/paftools.js
        FILENAME=$(basename ~{bamFile})
        if [[ ~{primaryOnly} = "no" ]]
        then
            k8 ${PAFTOOLS_PATH} sam2paf <(samtools view -h -q ~{minMAPQ} ~{bamFile}) > ${FILENAME%.*}.paf
        else
            k8 ${PAFTOOLS_PATH} sam2paf <(samtools view -h -q ~{minMAPQ} -F256 -F4 ~{bamFile}) > ${FILENAME%.*}.paf
        fi
    >>>
    runtime {
        docker: dockerImage
        memory: memSize + " GB"
        cpu: threadCount
        disks: "local-disk " + diskSize + " SSD"
        preemptible : preemptible
    }
    output{
        File pafFile = glob("*.paf")[0]
    }
}

