#!/bin/bash

function gen_diskuse_map(){
    local dum dum_ori dum_str curDir nfds ds d strT duT totalB_fs l2a s sh f dum_str_prev userT
    declare -A dum dum_ori

    curDir=`basename ${PWD}`
    # echo curDir=$curDir


    # >>>>>>>>>>>>>>>>>>>>>>> skip 
    if [[ ${PWD} =~ /\.git/ ]]; then
        return 1
    fi

    if [[ -e '.duqs_int' ]]; then
        totalSize=`du -sh | cut -f1`
        dum_str="([<total>]=)${totalSize}"
        sed -e "1i `date +%Y-%m-%d_%H:%M:%S`" -e "1i $dum_str" ${qsFile} > $qsFile
        return 0
    fi


    dirT=${PWD}
    while [[ ${dirT} != '/' ]]; 
    do
        if [[ $(dirname `dirname ${dirT}`) == $homePa ]]; then
            break
        fi
        dirT=`dirname $dirT`
    done
    dirN_L1=`basename $dirT`
    if [[ ${dirN_L1:0:1} == '.' ]]; then
        return 1
    fi

    # if [[ $(dirname `dirname ${PWD}`) == $homePa && ${curDir:0:1} == '.' && ${curDir} != '.' ]]; then
    #     return 1
    # fi

    ls -la > $tempFile
    nfds=`wc -l $tempFile | awk {'print $1'}`
    totalB=0
    ds=`grep -P '^d' $tempFile | awk '{print $9}'`  # directory lines
    for d in ${ds[@]}  # directory line
    do
        if [ ! -r $d ]; then
            continue
        fi
        if [ ! -e $d/${qsFile} ]; then
            continue
        fi
        if [[ $d == '.' || $d == '..' ]]; then
            continue
        fi
        
        strT=`sed -n '2p' $d/${qsFile}` # diskuse in quickSpace
        eval "dum_ori=$strT"
        duT=${dum_ori[<total>]}
        (( totalB += `human2Byte $duT`))
        echo totalB = $totalB
        dum[$d]=$duT
    done

    if [[ $nfds -gt 200 ]]; then
        totalB_fs=`awk 'BEGIN{sum=0}{if ($1 ~ /^-/ && $3 == "'$user'") sum += $5;}END{print sum}' $tempFile`
        (( totalB += totalB_fs ))
        dum[allFiles]=`byte2Human $totalB_fs`
    else
        while read LINE
        do
            l2a=(${LINE})
            s=${l2a[0]}
            (( totalB += s))
            sh=`byte2Human $s`
            f=${l2a[1]}
            if [[ `dirname ${PWD}` == $homePa  && ${f:0:1} == '.' ]]; then
                continue
            fi
            if [[ $f =~ \.duqs.* || $f == 'qsub_calSpaceR' || $f =~ calSpaceR\.o.* ]]; then
                continue
            fi
            dum[$f]=$sh
        done < <(awk '{if ($1 ~ /^-/ && $3 == "'$user'") print $5,$9}' $tempFile)
    fi
    dum[<total>]=`byte2Human $totalB`

    # --- output
    dum_str='('
    for i in ${!dum[@]}
    do
        dum_str+="[$i]=${dum[$i]} "
    done
    dum_str+=')'

    if [[ -e ${qsFile} && `stat -c %s ${qsFile}` -gt 0 ]]; then
        dum_str_prev=`sed -n '2p' ${qsFile}`
        if [ "$dum_str" != "$dum_str_prev" ]; then
            sed -e "1i `date +%Y-%m-%d_%H:%M:%S`" -e "1i $dum_str" ${qsFile} > $tempFile
        else
            sed -e "1c `date +%Y-%m-%d_%H:%M:%S`" ${qsFile} > $tempFile
        fi
        cat $tempFile > $qsFile
    else
        if [[ ${#dum[@]} == 1 ]]; then
            return 0
        fi
        if [[ ! -w . ]]; then
            # echo "weired directory <${PWD}> which has $user files but has no w-authority for $user"
            # return 1
            userT=`stat -c %U .`
            # echo userT=$userT, target file=${PWD}/${qsFile} >> ${workDir}/${qsFile}.log
            # echo "echo `date +%Y-%m-%d_%H:%M:%S` > ${PWD}/${qsFile}; echo $dum_str >> ${PWD}/${qsFile}; chmod 666 ${PWD}/${qsFile}" >> ${workDir}/${qsFile}.log
            ssh $userT@localhost "echo `date +%Y-%m-%d_%H:%M:%S` > ${PWD}/${qsFile}; echo '"$dum_str"' >> ${PWD}/${qsFile}; chmod 666 ${PWD}/${qsFile}"
        else
            # echo curT=${PWD} >> ${workDir}/${qsFile}.log
            echo `date +%Y-%m-%d_%H:%M:%S` > ${qsFile}
            echo $dum_str >> ${qsFile}
            chmod 666 $qsFile
        fi
    fi

    return 0

}

function update_diskuse_map(){
    local chTot chDir tarDir strT bname dum_ori totalTmp dum_str dum_str_prev size_ori total_ori size_delta total_new
    declare -A dum_ori
    cd $1
    gen_diskuse_map
    chTot=`byte2Human $totalB`
    echo chTot=$chTot
    cd $workDir
    chDir=$1
    tarDir=`dirname $1`
    while [[ 1 ]]; do
        echo tarDir=$tarDir, chDir=$chDir
        strT=`sed -n '2p' $tarDir/${qsFile}` # diskuse in quickSpace
        eval "dum_ori=$strT"
        bname=`basename $chDir`
        echo bname=$bname
        size_ori=${dum_ori[$bname]}
        echo size_ori=$size_ori
        size_delta=`sumSize $chTot -$size_ori`
        echo size_delta=$size_delta
        total_ori=${dum_ori[<total>]}
        echo total_ori=$total_ori
        total_new=`sumSize $total_ori $size_delta`
        echo total_new=$total_new
        dum_ori[$bname]=$chTot
        # echo to_be_sum ${dum_ori[@]}
        # totalTmp=`sumSize ${dum_ori[@]}`
        dum_ori[<total>]=$total_new
        
        # --- output
        dum_str='('
        for i in ${!dum_ori[@]}
        do
            dum_str+="[$i]=${dum_ori[$i]} "
        done
        dum_str+=')'

        dum_str_prev=`sed -n '2p' $tarDir/${qsFile}`
        dum_time_prev=`sed -n '1p' $tarDir/${qsFile}`
        if [[ ${modified_qsfs[$tarDir/${qsFile}]} == "" ]]; then
            modified_qsfs[$tarDir/${qsFile}]=1
            if [ "$dum_str" != "$dum_str_prev" ]; then
                sed -e "1i `date +%Y-%m-%d_%H:%M:%S`" -e "1i $dum_str" $tarDir/${qsFile} > $tempFile
            else
                sed -e "1c `date +%Y-%m-%d_%H:%M:%S`" $tarDir/${qsFile} > $tempFile
            fi
            cat $tempFile > $tarDir/$qsFile
        else
            sed -e "1c `date +%Y-%m-%d_%H:%M:%S`" -e "2c $dum_str" $tarDir/${qsFile} > $tempFile
        fi


        if [[ $tarDir == '.' ]]; then
            break
        fi
        chDir=$tarDir
        chTot=$total_new
        tarDir=`dirname $chDir`
    done
}