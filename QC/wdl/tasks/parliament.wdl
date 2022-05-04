version 1.0

# This is a task level wdl workflow to run the program PARLIAMENT

workflow runParliament{
    input{
        File inputBam
        File refGenome
        File indexBam
        File indexGenome

        String? prefix
        Boolean? filterShortContigs
        String? otherArgs
        String? dockerImage
      }
    call Parliament{
        input:
            inputBam = inputBam,
            refGenome = refGenome,
            indexBam = indexBam,
            indexGenome = indexGenome,
            prefix = prefix,
            filterShortContigs = filterShortContigs,
            otherArgs = otherArgs,
            dockerImage = dockerImage
    }
  output{
    File ParliamentVCF = Parliament.ParliamentVCF
  }
}

task Parliament{
  input{
    File inputBam
    File indexBam
    File refGenome
    File indexGenome

    String? prefix
    Boolean? filterShortContigs
    String? otherArgs = "--breakdancer --breakseq --manta --cnvnator --lumpy --delly_deletion --genotype --svviz_only_validated_candidates"

    String dockerImage = "dnanexus/parliament2@sha256:9076e0cb48f1b0703178778865a6f95df48a165fbea8d107517d36b23970a3d3" # latest
    Int memSizeGB = 128
    Int threadCount = 64
    Int diskSizeGB = 128
  }

  parameter_meta{
    inputBam: "Illumina BAM file for which to call structural variants containing mapped reads."
    indexBam: "Corresponding index for the Illumina BAM file."
    refGenome: "Reference file that matches the reference used to map the Illumina inputs."
    indexGenome: "Corresponding index for the reference genome file."
    prefix: "If provided, all output files will start with this. If absent, the base of the BAM file name will be used."
    filterShortContigs: "If true, contigs shorter than 1 MB will be filtered out. Default is true. Enter false to keep short contigs."
    otherArgs: "Other optional arguments can be defined here. Refer to https://github.com/dnanexus/parliament2#help for more details."
    }

  command <<<
      # exit when a command fails, fail with unset variables, print commands before execution
        set -eux -o pipefail

        # copy input files to the /in folder to make them accessible to the parliament2.py script
        cp ~{inputBam} /home/dnanexus/in
        cp ~{refGenome} /home/dnanexus/in
        cp ~{indexBam} /home/dnanexus/in
        cp ~{indexGenome} /home/dnanexus/in
        
        # pass filter_short_contigs argument based on user input, default being true and Run PARLIAMENT
        if ["~{filterShortContigs}" = "false"]; then
            python /home/dnanexus/parliament2.py --bam ~{basename(inputBam)} -r ~{basename(refGenome)} --prefix ~{prefix} --bai ~{basename(indexBam)} --fai ~{basename(indexGenome)} ~{otherArgs}
        else
            python /home/dnanexus/parliament2.py --bam ~{basename(inputBam)} -r ~{basename(refGenome)} --prefix ~{prefix} --bai ~{basename(indexBam)} --fai ~{basename(indexGenome)} --filter_short_contigs ~{otherArgs}
        fi

        # copy output files to output folder
        cp /home/dnanexus/out/~{prefix}.combined.genotyped.vcf .
  >>>
  output{
    File ParliamentVCF = "~{prefix}.combined.genotyped.vcf"
  }
  runtime{
    memory: memSizeGB + " GB"
    cpu: threadCount
    disks: "local-disk " + diskSizeGB + " SSD"
    docker: dockerImage
    preemptible: 1
  }
}
