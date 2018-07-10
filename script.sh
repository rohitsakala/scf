#!/bin/bash

##### Constants

SCF_DIR="/data/scf"
RELEASE_FILES=${SCF_DIR}"/src/*"

release=
blob=
blobPath=
vendorName=
shaSum=
oldSha=
fingerprint=
rel=
declare -a releaseList=()
declare -a blobList=()

#### Functions

usage()
{
	echo "usage: ./script.sh [[[-r releaseName ] | [-v vendorName] [-b blobName ] [-p NewblobPath]] [-h help]]"
}

getReleaseList()
{
	for f in $RELEASE_FILES
	do
		if [[ $f == *release* ]]
		then
			if [[ $f == *uaa-fissile* ]]
			then 
				for fu in $f/src/*
				do
					if [[ $fu == *release* ]]
					then
						releaseList=("${releaseList[@]}" $fu)
					fi
				done
			else
				releaseList=("${releaseList[@]}" $f)
			fi
		else
			for fs in $f/*
			do
				if [[ $fs == *release* ]]
				then
					releaseList=("${releaseList[@]}" $fs)
				fi
			done
		fi
	done
}

getBlobList()
{
	for rel in "${releaseList[@]}"
	do
		while read bl; do
			if [[ $bl == */* ]]
			then
				bl=`echo $bl | cut -d ':' -f 1`
				blobList=("${blobList[@]}" $bl)
			fi
		done < $rel/config/blobs.yml
	done
}

replaceSha()
{
	for rel in "${releaseList[@]}"
	do
		if [[ $rel == *"$release" ]]
		then
			break
		fi
	done
	found=false
	while read bl
	do
		if [[ $blob: == $bl ]] || [[ $found == true ]]
		then
			found=true
			if [[ $bl == *sha256* ]]
			then
				shaOld=`echo $bl | cut -d ':' -f 3`
				sed -i "s/$bl/sha: sha256:$shaSum256/g" $rel/config/blobs.yml
				break
			elif [[ $bl == *sha* ]]
			then
				shaOld=`echo $bl | cut -d ' ' -f 2`
				sed -i "s/$bl/sha: $shaSum/g" $rel/config/blobs.yml
				break
			fi
		fi
	done < $rel/config/blobs.yml
}

replaceFile()
{
	for rel in "${releaseList[@]}"
        do
                if [[ $rel == *"$release" ]]
                then
                        break
                fi
        done
	cp $blobPath $rel/blobs/$blob

}

replaceFileVendor()
{
	cd ./output/bosh-cache/
	mkdir temp
	tar xvf $oldSha -C temp
	cd ./temp
	goPrevious=`ls  | grep "go"`
	goNew=`echo $goPrevious | sed 's/amd64/s390x/g'`
	wget -O $goPrevious https://dl.google.com/go/$goNew
	name="$oldSha".tar.gz
	tar -zcvf $name *
	mv $name ../
	cd ..
	rm -r temp
	rm -r $oldSha
	mv $name $oldSha
	shaSum=`sha1sum $oldSha | cut -d ' ' -f 1`
	mv $oldSha $shaSum
	cd ../..
}

getFingerprintSha()
{
	for rel in "${releaseList[@]}"
        do
                if [[ $rel == *"$release" ]]
                then
                        break
                fi
        done
	specPath=$rel/packages/$vendorName/spec.lock
	while read l
	do
		if [[ $l == *fingerprint* ]]
		then
			fingerprint=`echo $l | cut -d ' ' -f 2`
		fi
	done < $specPath
	releaseName=`echo $release | cut -d '-' -f 1`
        indexPath=$rel/.final_builds/packages/$vendorName/index.yml
	while read l
        do
                if [[ $l == *sha* ]]
                then
                        oldSha=`echo $l | cut -d ' ' -f 2`
                        break
                fi
        done < $indexPath
}


getSha()
{
	releaseName=`echo $release | cut -d '-' -f 1`
	indexPath=$rel/dev_releases/$releaseName/index.yml
	version=
	while read l
	do 
		if [[ $l == *version* ]] 
		then
			version=`echo $l | cut -d ' ' -f 2`
			break
		fi
	done < $indexPath
	found=false
	fileName=$releaseName-"$version".yml
	versionPath=$rel/dev_releases/$releaseName/$fileName
	while read l
	do 
		if [[ $l == *"name: golang-1.9-linux"* ]] || [[ $found == true ]]
		then
			found=true
			if [[ $l == *sha* ]]
			then
				sed -i "s/$l/sha1: $shaSum/g" $versionPath
				break
			fi
		fi
	done < $versionPath
	id=`ls /data/scf/output/fissile/compilation/`
	rm -rf /data/scf/output/fissile/$id/$fingerprint
}

##### Main

if [[ "$#" -ne 6 && "$#" -ne 4 ]]
then
	usage
	exit 1
fi


while [ "$1" != "" ]; do
    case $1 in
        -r | --release )        shift
                                release=$1
                                ;;
        -b | --blob )           shift
				blob=$1
                                ;;
	-p | --blobPath )       shift
				blobPath=$1
				;;
        -v | --vendorName )     shift
				vendorName=$1
				;;
        -h | --help )           usage
                                exit
                                ;;
        * )                     usage
                                exit 1
    esac
    shift
done

getReleaseList
getBlobList

# Calculate SHA of new blob
shaSum=$(sha1sum $blobPath  | awk '{ print $1 }')
shaSum256=$(sha256sum $blobPath  | awk '{ print $1 }')

if [ -n "$vendorName" ]
then
	#Get fingerprint and oldSha
        getFingerprintSha

	#Replace blob in tar bosh cache
	replaceFileVendor	

	# Make releases
	make releases

	# Replace sha1 in dev releases
	getSha
	
	# Make compile
	make compile
else
	# Modify blob.yml
	replaceSha

	# Replace file
	replaceFile
fi

