#!/bin/bash
photosDirectory="photos"
databaseDirectory="database"
albums=$(ls -1t $photosDirectory)

mv ../index.html ../index.html.save
mv ../make.html ../index.html

# index.json
echo "Generating index..."
:> "$databaseDirectory/index.json.tmp"
echo -n "[" >> "$databaseDirectory/index.json.tmp"
first=1

OLDIFS=${IFS}
IFS=$'\n'
for album in $albums
do
	if [ -d "$photosDirectory/$album" ]
	then
		echo "Creating album \"$album\"..."
		if [ $first -eq 0 ]
		then
			echo -n "," >> "$databaseDirectory/index.json.tmp"
		else
			first=0
		fi

		echo -n "{" >> "$databaseDirectory/index.json.tmp"
		echo -n "\"name\":\"${album}\"," >> "$databaseDirectory/index.json.tmp"
		echo -n "\"count\":$(ls -1 "$photosDirectory/$album" | grep -v "_web\.\(gif\|jpg\)$" | wc -l)," >> "$databaseDirectory/index.json.tmp"
		# The best photo is selected to be the thumb of the album
		firstImage=`ls -1 "$photosDirectory/$album" | grep -v "_web\.\(gif\|jpg\)$" | xargs -n1 -I'{}' bash -c "exiv2 -Pkv print \"$photosDirectory/$album/{}\" | grep 'Xmp.xmp.Rating' | sed 's/^[^ ]*\s*//' | xargs -I'}{' echo '}{|{}'" | sort -r | head -n1 | cut -f2 -d'|'`

		echo -n "\"thumb\":\"${firstImage%.*}_web.gif\"," >> "$databaseDirectory/index.json.tmp"
		echo -n "\"date\":$(exiv2 -Pkv print "$photosDirectory/$album/$firstImage" | grep "Exif.Photo.DateTimeOriginal" | sed 's/^[^ ]*\s*//' | sed 's/^\([0-9]*\):\([0-9]*\):\([0-9]*\)\s/\1-\2-\3 /' | xargs -I'{}' date --date="{}" +%s)" >> "$databaseDirectory/index.json.tmp"
		echo -n "}" >> "$databaseDirectory/index.json.tmp"
	else
		echo "Ignoring \"$album\": not a directory"
	fi
done
echo "]" >> "$databaseDirectory/index.json.tmp"
mv "$databaseDirectory/index.json.tmp" "$databaseDirectory/index.json"
echo "Index generated."

for album in $albums
do
	if [ -d "$photosDirectory/$album" ]
	then
		echo "Generating \"$album\" album index..."
		indexName="$databaseDirectory/$(echo "$album" | unaccent UTF-8 | tr '[A-Z]' '[a-z]' | sed 's/\s/_/g').json"
		:> "$indexName.tmp"
		echo -n "[" >> "$indexName.tmp"

		images=$(find "${photosDirectory}/${album}/" -type f -print0 | xargs -0 -n1 basename | grep -v "_web\.\(gif\|jpg\)$" | sort)
		first=1
		for image in $images
		do
			if [ $first -eq 0 ]
			then
				echo -n "," >> "$indexName.tmp"
			else
				first=0
			fi

			echo "Processing image \"${image}\"..."

			i300="${image%.*}_web.gif"
			i1024="${image%.*}_web.jpg"

			if [ ! -e "$photosDirectory/$album/$i300" -o "$photosDirectory/$album/$i300" -ot "$photosDirectory/$album/$image" ]
			then
				echo "Generating thumbnail for ${image}..."
				convert "$photosDirectory/$album/$image" -thumbnail 300x300 "$photosDirectory/$album/$i300"
			fi

			if [ ! -e "$photosDirectory/$album/$i1024" -o "$photosDirectory/$album/$i1024" -ot "$photosDirectory/$album/$image" ]
			then
				echo "Generating web sized image for ${image}..."
				convert "$photosDirectory/$album/$image" -thumbnail 1024x768 -quality 90 "$photosDirectory/$album/$i1024"
			fi

			information=$(exiv2 -Pkv print "$photosDirectory/$album/$image" | grep "Exif.Photo.LensModel\|Exif.Photo.ExposureTime\|Exif.Photo.FNumber\|Exif.Photo.ISOSpeedRatings\|Exif.Photo.DateTimeOriginal\|Exif.Photo.Flash\|Exif.Image.Model")
			info1024=$(exiv2 print "$photosDirectory/$album/$i1024" 2> /dev/null | grep "^Image size" | sed 's/Image size\s*:\s*\([0-9]*\)\s*x\s*\([0-9]*\)/\1|\2/') 
			info300=$(exiv2 print "$photosDirectory/$album/$i300" 2> /dev/null | grep "^Image size" | sed 's/Image size\s*:\s*\([0-9]*\)\s*x\s*\([0-9]*\)/\1|\2/') 

			echo -n "{" >> "$indexName.tmp"
			echo -n "\"original_name\":\"${image}\"," >> "$indexName.tmp"
			echo -n "\"name\":\"${i1024}\"," >> "$indexName.tmp"
			echo -n "\"width\":$(echo "$info1024" | cut -f1 -d'|')," >> "$indexName.tmp"
			echo -n "\"height\":$(echo "$info1024" | cut -f2 -d'|')," >> "$indexName.tmp"
			echo -n "\"thumb\":\"${i300}\"," >> "$indexName.tmp"
			echo -n "\"thumb_width\":$(echo "$info300" | cut -f1 -d'|')," >> "$indexName.tmp"
			echo -n "\"thumb_height\":$(echo "$info300" | cut -f2 -d'|')," >> "$indexName.tmp"
			echo -n "\"model\":\"$(echo "$information" | grep "Exif.Image.Model" | sed 's/^[^ ]*\s*//')\"," >> "$indexName.tmp"
			echo -n "\"lens\":\"$(echo "$information" | grep "Exif.Photo.LensModel" | sed 's/^[^ ]*\s*//')\"," >> "$indexName.tmp"
			echo -n "\"date\":$(echo "$information" | grep "Exif.Photo.DateTimeOriginal" | sed 's/^[^ ]*\s*//' | sed 's/^\([0-9]*\):\([0-9]*\):\([0-9]*\)\s/\1-\2-\3 /' | xargs -I'{}' date --date="{}" +%s)," >> "$indexName.tmp"
			echo -n "\"exposure_time\":\"$(echo "$information" | grep "Exif.Photo.ExposureTime" | sed 's/^[^ ]*\s*//')\"," >> "$indexName.tmp"
			echo -n "\"aperture\":`echo -e "scale=1\n"$(echo "$information" | grep "Exif.Photo.FNumber" | sed 's/^[^ ]*\s*//') | bc`," >> "$indexName.tmp"
			echo -n "\"iso\":$(echo "$information" | grep "Exif.Photo.ISOSpeedRatings" | sed 's/^[^ ]*\s*//')," >> "$indexName.tmp"
			flash="true"
			if [ "$(echo "$information" | grep "Exif.Photo.Flash" | sed 's/^[^ ]*\s*//')" = "16" ]
			then
				flash="false"
			fi
			echo -n "\"flash\":$flash" >> "$indexName.tmp"
			echo -n "}" >> "$indexName.tmp"
		done

		echo -n "]" >> "$indexName.tmp"
		mv "$indexName.tmp" "$indexName"
		echo "\"$album\" album index generated."
	fi
done
IFS=${OLDIFS}

mv ../index.html ../make.html
mv ../index.html.save ../index.html
