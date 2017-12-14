#!/bin/bash

if [ "$1" == '' ] || [ "$1" == '-h' ] ; then
    echo "usage :"
    echo -e "\t$0 deploy"
    echo -e "\t$0 render FILENAME"
    echo "for now, the IPs are determined automatically."
    exit 0
fi

passwordFile=${2:-'pass'}
echo "passwordFile : $pass"
blenderArchive='blender.tar.gz'
blenderProfile='~/.config/blender/'

home="/home/$USER"

function deploy(){
    i=$1

    addr="$USER@134.214.253.$i"
    echo $addr
    sshpass -f $passwordFile ssh -o StrictHostKeyChecking=no $addr mkdir -p "$home/bin"
    sshpass -f $passwordFile scp -r -o StrictHostKeyChecking=no $blenderArchive demo@134.214.253.$i:"$home/bin/"
    sshpass -f $passwordFile ssh -o StrictHostKeyChecking=no $addr tar xzf "$home/bin/blender.tar.gz"
    sshpass -f $passwordFile ssh -o StrictHostKeyChecking=no $addr mv "$home/blender" "$home/bin/"
    sshpass -f $passwordFile ssh -o StrictHostKeyChecking=no $addr rm "$home/bin/blender.tar.gz"
    sshpass -f $passwordFile ssh -o StrictHostKeyChecking=no $addr rm -rf $blenderProfile
    sshpass -f $passwordFile scp -r -o StrictHostKeyChecking=no "/home/demo/.config/blender" demo@134.214.253.$i:$blenderProfile
    
}

function copyFile(){
    file=$1
    machine=$2
    sshpass -f $passwordFile scp -o StrictHostKeyChecking=no $file $machine:/tmp/
    # sshpass -f $passwordFile ssh -o StrictHostKeyChecking=no $machine killall blender
}

function killBlender(){
    machine=$1
    sshpass -f $passwordFile ssh -o StrictHostKeyChecking=no $machine killall -q blender
}

function clean(){
    machine=$1
    sshpass -f $passwordFile ssh -o StrictHostKeyChecking=no $machine killall blender
}

# here the file is already on the distant machine
function render(){
    file=$1
    machine=$2
    frame=$3
    printf -v pngName "/tmp/render_%04d.png" $frame

    filename=$(basename $file)
    echo "rendering $file on $machine, frame $frame"
    
    sshpass -f $passwordFile ssh -o StrictHostKeyChecking=no $machine $home/bin/blender/blender -b /tmp/$filename -o //render_####.png -f $frame >/dev/null
    sshpass -f $passwordFile scp -o StrictHostKeyChecking=no $machine:$pngName ./
    
    nextFrame=$(cat $nextFrameFile)
    echo $((nextFrame+1)) > $nextFrameFile

    if [ "$nextFrame" -lt "$maxFrame" ]
    then
        render $file $machine $nextFrame
    else
        echo -n "fini pour $machine !"
        machinesUsed=$(cat /tmp/machinesUsed)
        machinesUsed=$((machinesUsed-1))
        echo $machinesUsed > /tmp/machinesUsed
        if [ $machinesUsed -eq 0 ] ; then
            echo -en "\nrendu fini !"
        elif [ $machinesUsed -lt 0 ] ; then
            echo -n "testicule dans potage"
        else
            echo -n " - $machinesUsed frames restantes"
        fi
        echo ""

    fi
}

machines=(34 35 36 37 38 39 40 41 42 43 44 45 47 48) #46 va se faire mettre
nbMachines=${#machines[@]}


if [ "$1" == "deploy" ] ; then
    start=134
    end=145

    for ((i=$start;i<=end;i++))
    do
        echo "deploying on $i"
        deploy $i
    done
elif [ "$1" = "render" ] ; then
    nextFrameFile="/dev/shm/nextFrame"
    echo $nbMachines > $nextFrameFile
    maxFrame=100
    i=1
    echo ${#machines[@]} > /tmp/machinesUsed
    for m in ${machines[@]}; do
        ip="134.214.253.1$m"
        copyFile $2 $ip
        render $2 $ip $i &
        i=$((i+1))
    done
    while [ $(cat /tmp/machinesUsed) -gt 0 ] ; do
        sleep 1
    done
elif [ "$1" = "kill" ] ; then
    for m in ${machines[@]}; do
        ip="134.214.253.1$m"
        echo "killing Blender on $ip"
        killBlender $ip
    done
else
    echo "tough luck, buddy."
fi
