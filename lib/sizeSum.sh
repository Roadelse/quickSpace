#!/bin/bash

sum(){
    echo $@ | awk 'BEGIN{sum=0}{
                                i = 1
                                while(i <= NF){
                                    sum += $i
                                    i += 1
                                }
                                print sum
                                }'
    
}


human2Byte(){
echo $1 | awk '{
    ex = index("KMGTPEZY", substr($1, length($1)))
    val = substr($1, 0, length($1) - 1)

    prod = val * 2^(ex * 10)

    sum += prod
}
END {print int(sum)}'

}

byte2Human(){
echo $1 | awk 'BEGIN{OFS="";a[1]="K"; a[2]="M"; a[3]="G"; a[4]="T"; a[5]="P"; a[6]="E"; a[7]="Z"; a[8]="Y"}{
tp = $1
ii = 0
while (tp >= 1024){
tp = tp / 1024
ii = ii + 1
}
printf("%.1f%c",tp,a[ii])
}'
}

sumSize(){
    paramsLen=$#
    As=($@)
    # echo ${As[@]}
    for ((i=1; i <= $paramsLen; i++))
    do
        # eval echo \$$i
        (( j = i - 1 ))

        As[$j]=`human2Byte ${!i}`
    done
#    echo ${As[@]}

   SUM=`sum ${As[@]}`
   SUM=`byte2Human $SUM`
   echo $SUM
    }
