sourcefile=$1
destfile=$2

# Overly simple validation
if [ ! -e "$sourcefile" ]; then
  echo 'Please provide an existing input file.'
  exit
fi

if [ "$destfile" == "" ]; then
  echo 'Please provide an output preview file name.'
  exit
fi

# Detect destination file extension
extension=${destfile#*.}

# Get video length in seconds
length=$(ffprobe $sourcefile  -show_format 2>&1 | sed -n 's/duration=//p' | awk '{print int($0)}')

# Start 20 seconds into the video to avoid opening credits (arbitrary)
starttimeseconds=20

# Mini-snippets will be 2 seconds in length
snippetlengthinseconds=2

# We'll aim for 5 snippets spread throughout the video
desiredsnippets=5

# Ensure the video is long enough to even bother previewing
minlength=$(($snippetlengthinseconds*$desiredsnippets))

# Video dimensions (these could probably be command line arguments)
dimensions=640:-1

# Temporary directory and text file where we'll store snippets
# These will be cleaned up and removed when the preview image is generated
tempdir=snippets
listfile=list.txt

# Display and check video length
echo 'Video length: ' $length
if [ "$length" -lt "$minlength" ]
then
  echo 'Video is too short.  Exiting.'
  exit
fi

# Loop and generate video snippets
mkdir $tempdir
interval=$(($length/$desiredsnippets-$starttimeseconds))
for i in $(seq 1 $desiredsnippets)
  do
    # Format the second marks into hh:mm:ss format
    start=$(($(($i*$interval))+$starttimeseconds))
    formattedstart=$(printf "%02d:%02d:%02d\n" $(($start/3600)) $(($start%3600/60)) $(($start%60)))
    echo 'Generating preview part ' $i $formattedstart
    # Generate the snippet at calculated time
    ffmpeg -i $sourcefile -vf scale=$dimensions -preset fast -qmin 1 -qmax 1 -ss $formattedstart -t $snippetlengthinseconds $tempdir/$i.$extension &>/dev/null
done

# Concat videos
echo 'Generating final preview file'

# Generate a text file with one snippet video location per line
# (https://trac.ffmpeg.org/wiki/Concatenate)
for f in $tempdir/*; do echo "file '$f'" >> $listfile; done

# Concatenate the files based on the generated list
ffmpeg -f concat -safe 0 -i $listfile -c copy $destfile &>/dev/null

echo 'Done!  Check ' $destfile '!'

# Cleanup
rm -rf $tempdir $listfile
