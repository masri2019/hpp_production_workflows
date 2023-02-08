version 1.0


workflow runHiCHifiasm{
    call hicHifiasm
}

# hifiasm HiC steps
# 1st: pass HiFi / not need to pass UL and HiC (extraOptions="--bin-only")
# 2nd: pass UL and fake HiFi / not need to pass HiC (extraOptions="--bin-only")
# 3rd: pass UL, fake HiFi and HiC
task hicHifiasm {
    input{
        Array[File]? childReadsHiC1
        Array[File]? childReadsHiC2
        Array[File] childReadsHiFi
        Array[File]? childReadsUL
        Int? homCov
        String childID
	String? extraOptions
        File? inputBinFilesTarGz
        # runtime configurations
        Int memSizeGB
        Int threadCount
        Int diskSizeGB
        Int preemptible
        String dockerImage
        String zones
    }
    command <<<
        set -o pipefail
        set -e
        set -u
        set -o xtrace

        ## if bin files are given we have to extract them in the directory where hifiasm is being run
        ## this enables hifiasm to skip the time-consuming process of finding read overlaps
        if [ ! -v ~{inputBinFilesTarGz} ]; then
            tar -xzf ~{inputBinFilesTarGz} --strip-components 1
            rm -rf ~{inputBinFilesTarGz}
        fi

        ## run trio hifiasm https://github.com/chhylp123/hifiasm
        # If ONT ultra long reads are provided
        if [[ -n "~{sep="" childReadsUL}" ]]; then
            if [[ -n "~{sep="" childReadsHiC1}" ]]; then 
                # for the 3nd step
                hifiasm ~{extraOptions} -o ~{childID} --ul ~{sep="," childReadsUL} --hom-cov ~{homCov} -t~{threadCount} --h1 "~{sep="," childReadsHiC1}" --h2 "~{sep="," childReadsHiC2}"  ~{sep=" " childReadsHiFi}
            else 
                # for the 2rd step
                hifiasm ~{extraOptions} -o ~{childID} --ul ~{sep="," childReadsUL} --hom-cov ~{homCov} -t~{threadCount} ~{sep=" " childReadsHiFi}           
            fi
        else  
            # for the 1st step
            hifiasm ~{extraOptions} -o ~{childID} -t~{threadCount} ~{sep=" " childReadsHiFi}
        fi

        #Move bin and gfa files to saparate folders and compress them 
        mkdir ~{childID}.raw_unitig_gfa
        mkdir ~{childID}.pat.contig_gfa
        mkdir ~{childID}.mat.contig_gfa
        mkdir ~{childID}.binFiles

        # before hardlinking gfa files to the corresponding directory make sure they exist
        # first and second step of hifiasm does not output gfa files
        if [[ -n $(find . -maxdepth 1 -iname "*.hap1.p_ctg.*") ]];
        then
            ln ~{childID}.dip.r_utg.* ~{childID}.raw_unitig_gfa
            ln *.hap1.p_ctg.* ~{childID}.pat.contig_gfa
            ln *.hap2.p_ctg.* ~{childID}.mat.contig_gfa
        else
            # To avoid making a separete new task for steps 1 and 2 of hifiasm
            # we make empty gfa files since we cannot have optional outputs in wdl
            touch empty.hap1.p_ctg.gfa
            touch empty.hap2.p_ctg.gfa
        fi

        ln *.bin ~{childID}.binFiles
        
        
        # make archives
        tar -cf ~{childID}.raw_unitig_gfa.tar ~{childID}.raw_unitig_gfa
        tar -cf ~{childID}.pat.contig_gfa.tar ~{childID}.pat.contig_gfa
        tar -cf ~{childID}.mat.contig_gfa.tar ~{childID}.mat.contig_gfa
        tar -cf ~{childID}.binFiles.tar ~{childID}.binFiles
        
        # compress
        pigz -p~{threadCount} ~{childID}.raw_unitig_gfa.tar
        pigz -p~{threadCount} ~{childID}.pat.contig_gfa.tar
        pigz -p~{threadCount} ~{childID}.mat.contig_gfa.tar
        pigz -p~{threadCount} ~{childID}.binFiles.tar
    >>>

    runtime {
        docker: dockerImage
        memory: memSizeGB + " GB"
        cpu: threadCount
        disks: "local-disk " + diskSizeGB + " SSD"
        preemptible : preemptible
        cpuPlatform: "Intel Cascade Lake"
        zones : zones
    }

    output {
        File outputPaternalGfa = glob("*.hap1.p_ctg.gfa")[0]
        File outputMaternalGfa = glob("*.hap2.p_ctg.gfa")[0]
        File outputPaternalContigGfa = "~{childID}.pat.contig_gfa.tar.gz"
        File outputMaternalContigGfa = "~{childID}.mat.contig_gfa.tar.gz"
        File outputRawUnitigGfa = "~{childID}.raw_unitig_gfa.tar.gz"
        File outputBinFiles = "~{childID}.binFiles.tar.gz"
    }
}

