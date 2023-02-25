version 1.0


workflow verkko_consensus_from_gfase {

    call finalize_gfase_verkko
    
    output{
        File final_gfase_folder = finalize_gfase_verkko.final_gfase_folder
    }
}

task finalize_gfase_verkko {
    
    input {
        File run_folder
        Array[File] input_hifi
        Array[File] input_nanopore
        File phase_csv

        String name = "assembly"
        String tag  = "verkko_gfase"

        Int threadCount = 24
        Int memSizeGB   = 180
        Int diskSizeGB  = 3500
        Int preemptible = 0
    }

    command <<<

        set -eux -o pipefail
        
        ## Neccesary so conda environment will activate...
        source ~/.bashrc

        ## localize nanopore reads to one directory
        ont_files=(~{sep=" " input_nanopore})

        mkdir ont 
        
        for ont_file in ${ont_files[@]};
        do
          cp $ont_file ont/
        done

        ## localize HiFi reads to one directory
        hifi_files=(~{sep=" " input_hifi})
        
        mkdir hifi 

        for hifi_file in ${hifi_files[@]};
        do
            ## Have to copy so I can set timestamp
            cp $hifi_file hifi/
        done


        ## Set modtime to a few years ago so it doesn't trigger snakemake
        touch -a -m -t 202001011205.02 hifi/*
        touch -a -m -t 202001011205.02 ont/*


        ## extract tar w/ snakemake run to cwd
        tar xvf ~{run_folder} --directory ./

        new_run_folder="rephase_folder"
        prior_run_folder="assembly"
        verkko="/root/miniconda3/envs/verkko_hic/"
        
        mkdir -p ${new_run_folder}/6-rukki

        awk 'BEGIN \
             { \
                OFS="\n"; \
             } \
             ($1 == "S") && ($3 != "*") \
             { \
                  print ">"$2, $3; \
             }' \
        < ${prior_run_folder}/5-untip/unitig-popped-unitig-normal-connected-tip.gfa \
        > ${new_run_folder}/6-rukki/unitig-popped-unitig-normal-connected-tip.fasta

        #
        #  Inject coverage into the graph.
        #

        awk < ${prior_run_folder}/5-untip/unitig-popped-unitig-normal-connected-tip.gfa \
          'BEGIN \
           { \
             FS="[ \t]+"; OFS="\t"; \
           } \
           { \
             if ($1 == "S") { \
               print "S", $2, "*", "LN:i:"length($3); \
             } else { \
               print $0; \
             } \
           }' \
        | \
        $verkko/lib/verkko/scripts/inject_coverage.py --allow-absent \
          ${prior_run_folder}/5-untip/unitig-popped-unitig-normal-connected-tip.hifi-coverage.csv \
        > ${new_run_folder}/6-rukki/unitig-popped-unitig-normal-connected-tip.noseq.gfa


        ## Rewrite phase_csv to be in format Rukki expects
        echo -e "node\tmat\tpat\tmat:pat\tcolor" >${new_run_folder}/6-rukki/unitig-popped-unitig-normal-connected-tip.colors.csv
        cat ~{phase_csv} |awk -F "," '{if ($2 == -1) { print $1"\t0\t100000\t0:100000\t#8888FF"} else if ($2 == 1) { print $1"\t100000\t0\t100000:0\t#FF8888"}}' >> ${new_run_folder}/6-rukki/unitig-popped-unitig-normal-connected-tip.colors.csv

        #
        #  Run Rukki.  Once for Bandage input, once for Consensus.
        #

        params=""
        params="$params --init-assign out_init_ann.csv"
        params="$params --refined-assign out_refined_ann.csv"
        params="$params --final-assign out_final_ann.csv"
        params="$params --marker-sparsity 5000"
        params="$params --issue-sparsity 1000"
        params="$params --try-fill-bubbles"
        params="$params  --solid-ratio 1.5 --issue-ratio 1. --fillable-bubble-len 500000 --fillable-bubble-diff 1000 --solid-homozygous-cov-coeff 1.1"        

        if [ xtrio = xtrio ]; then
           params="$params --issue-len 200000  --marker-ratio 5. --issue-ratio 3. --issue-cnt 100"
        else
           params="$params --issue-len 2000000 --marker-ratio 3. --issue-ratio 2. --issue-cnt 1000"
        fi

        ## Call w/ new branch of Rukki
        /opt/rukki/target/release/rukki trio -g ${new_run_folder}/6-rukki/unitig-popped-unitig-normal-connected-tip.noseq.gfa -m ${new_run_folder}/6-rukki/unitig-popped-unitig-normal-connected-tip.colors.csv              -p ${new_run_folder}/6-rukki/unitig-popped-unitig-normal-connected-tip.paths.tsv $params
        /opt/rukki/target/release/rukki trio -g ${new_run_folder}/6-rukki/unitig-popped-unitig-normal-connected-tip.noseq.gfa -m ${new_run_folder}/6-rukki/unitig-popped-unitig-normal-connected-tip.colors.csv --gaf-format -p ${new_run_folder}/6-rukki/unitig-popped-unitig-normal-connected-tip.paths.gaf $params

        ## Call verkko to build consensus and get final assemblies
        verkko  \
            --paths ${new_run_folder}/6-rukki/unitig-popped-unitig-normal-connected-tip.paths.gaf \
            --assembly ${prior_run_folder} \
            -d ${new_run_folder}/final_asm \
            --local-memory ~{memSizeGB} \
            --local-cpus ~{threadCount} \
            --hifi hifi/*fast*.gz \
            --nano ont/*fast*.gz

        tar -cvf ~{name}_~{tag}.tar ${new_run_folder}

    >>>

    output {

        File final_gfase_folder = "~{name}_~{tag}.tar"
    }

    runtime {
        memory: memSizeGB + " GB"
        cpu: threadCount
        cpuPlatform: "Intel Cascade Lake"
        disks: "local-disk " + diskSizeGB + " SSD"
        docker: "humanpangenomics/verkko_for_gfase@sha256:9beccde8dc9416c34e69f1e9989b6eceddc6f983bbc0459d0fb20f0d95868924"
        preemptible: preemptible
    }
}