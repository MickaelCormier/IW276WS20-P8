#!/usr/bin/env bash
#
# Start an instance of the jetson-inference docker container.
# See below or run this script with -h or --help to see usage options.
#
# This script should be run from the root dir of the jetson-inference project:
#
#     $ cd /path/to/your/jetson-inference
#     $ docker/run.sh
#


show_help() {
    echo " "
    echo "usage: Starts the Docker container and runs a user-specified command"
    echo " "
    echo "   ./docker/run.sh --container DOCKER_IMAGE"
    echo "                   --volume HOST_DIR:MOUNT_DIR"
    echo "                   --run RUN_COMMAND"
    echo " "
    echo "args:"
    echo " "
    echo "   --help                       Show this help text and quit"
    echo " "
    echo "   -c, --container DOCKER_IMAGE Specifies the name of the Docker container"
    echo "                                image to use (default: 'nvidia-l4t-base')"
    echo " "
    echo "   -v, --volume HOST_DIR:MOUNT_DIR Mount a path from the host system into"
    echo "                                   the container.  Should be specified as:"
    echo " "
    echo "                                      -v /my/host/path:/my/container/path"
    echo " "
    echo "                                   (these should be absolute paths)"
    echo " "
    echo "   -r, --run RUN_COMMAND  Command to run once the container is started."
    echo "                          Note that this argument must be invoked last,"
    echo "                          as all further arguments will form the command."
    echo "                          If no run command is specified, an interactive"
    echo "                          terminal into the container will be provided."
    echo " "
}

die() {
    printf '%s\n' "$1"
    show_help
    exit 1
}

# find container tag from L4T version
source docker/tag.sh

# paths to some project directories
NETWORKS_DIR="data/networks"
CLASSIFY_DIR="python/training/classification"
DETECTION_DIR="python/training/detection/ssd"

DATASET_DIR="/home/p8/projects/dataset_panda/image_valid" # where the test image directory resides on the host
OUTPUT_DIR="/home/p8/projects/results" # output image directory on the host

DOCKER_ROOT="/jetson-inference"	# where the project resides inside docker

# generate mount commands
DATA_VOLUME="\
--volume $PWD/data:$DOCKER_ROOT/data \
--volume $PWD/$CLASSIFY_DIR/data:$DOCKER_ROOT/$CLASSIFY_DIR/data \
--volume $PWD/$CLASSIFY_DIR/models:$DOCKER_ROOT/$CLASSIFY_DIR/models \
--volume $PWD/$DETECTION_DIR/data:$DOCKER_ROOT/$DETECTION_DIR/data \
--volume $PWD/$DETECTION_DIR/models:$DOCKER_ROOT/$DETECTION_DIR/models \
--volume $PWD/detect_people:$DOCKER_ROOT/detect_people \
--volume $DATASET_DIR:$DOCKER_ROOT/data/images/test \
--volume $OUTPUT_DIR:$DOCKER_ROOT/$DETECTION_DIR/output"

# parse user arguments
USER_VOLUME=""
USER_COMMAND=""

while :; do
    case $1 in
        -h|-\?|--help)
            show_help    # Display a usage synopsis.
            exit
            ;;
        -c|--container)       # Takes an option argument; ensure it has been specified.
            if [ "$2" ]; then
                CONTAINER_IMAGE=$2
                shift
            else
                die 'ERROR: "--container" requires a non-empty option argument.'
            fi
            ;;
        --container=?*)
            CONTAINER_IMAGE=${1#*=} # Delete everything up to "=" and assign the remainder.
            ;;
        --container=)         # Handle the case of an empty --image=
            die 'ERROR: "--container" requires a non-empty option argument.'
            ;;
        -v|--volume)
            if [ "$2" ]; then
                USER_VOLUME=" -v $2 "
                shift
            else
                die 'ERROR: "--volume" requires a non-empty option argument.'
            fi
            ;;
        --volume=?*)
            USER_VOLUME=" -v ${1#*=} " # Delete everything up to "=" and assign the remainder.
            ;;
        --volume=)         # Handle the case of an empty --image=
            die 'ERROR: "--volume" requires a non-empty option argument.'
            ;;
        -r|--run)
            if [ "$2" ]; then
                shift
                USER_COMMAND=" $@ "
            else
                die 'ERROR: "--run" requires a non-empty option argument.'
            fi
            ;;
        --)              # End of all options.
            shift
            break
            ;;
        -?*)
            printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2
            ;;
        *)               # Default case: No more options, so break out of the loop.
            break
    esac

    shift
done

echo "CONTAINER:     $CONTAINER_IMAGE"
echo "DATA_VOLUME:   $DATA_VOLUME"
echo "USER_VOLUME:   $USER_VOLUME"
echo "USER_COMMAND:  $USER_COMMAND"

# check for V4L2 devices
V4L2_DEVICES=" "

for i in {0..9}
do
	if [ -a "/dev/video$i" ]; then
		V4L2_DEVICES="$V4L2_DEVICES --device /dev/video$i "
	fi
done

echo "V4L2_DEVICES:  $V4L2_DEVICES"

# run the container
sudo xhost +si:localuser:root

sudo docker run --runtime nvidia -it --rm --network host -e DISPLAY=$DISPLAY \
    -v /tmp/.X11-unix/:/tmp/.X11-unix \
    -v /tmp/argus_socket:/tmp/argus_socket \
    $V4L2_DEVICES $DATA_VOLUME $USER_VOLUME \
    $CONTAINER_IMAGE $USER_COMMAND

