version 1.0 

workflow runFitModel{
    call fitModel
    output {
       File probabilityTable = fitModel.probabilityTable 
    }
}
task fitModel {
    input {
        File counts
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

        FILENAME=$(basename ~{counts})
        PREFIX=${FILENAME%.counts}
        python3 ${FIT_MODEL_EXTRA_PY} --counts ~{counts} --output ${PREFIX}.table
    >>> 
    runtime {
        docker: dockerImage
        memory: memSize + " GB"
        cpu: threadCount
        disks: "local-disk " + diskSize + " SSD"
        preemptible : preemptible
    }
    output {
        File probabilityTable = glob("*.table")[0]
    }
}

