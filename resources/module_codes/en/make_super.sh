function create_super_img {
  local partition_type=$1  # Local variable partition_type, its value is the first parameter of the function
  local is_sparse=$2  # Local variable is_sparse, its value is the second parameter of the function

  # Calculate the total number of bytes of all files in the super folder
  local total_size=0
  for file in "$WORK_DIR/$current_workspace/Extracted-files/super/"*; do
    file_size_bytes=$(stat -c%s "$file")
    remainder=$(($file_size_bytes % 4096))
    if [ $remainder -ne 0 ]; then
      file_size_bytes=$(($file_size_bytes + 4096 - $remainder))
    fi
    total_size=$(($total_size + $file_size_bytes))
  done

  local extra_space=$(( 125 * 1024 * 1024 * 1024 / 100 ))

  # Adjust the value of total_size according to the partition type
  case "$partition_type" in
    "AB")
      total_size=$(((total_size + extra_space) * 2 ))
      ;;
    "ONLYA"|"VAB")
      total_size=$((total_size + extra_space))
      ;;
  esac
  clear

   while true; do
  # Display the total number of bytes of all files in the SUPER folder
    echo -e "\n   SUPER reference value: $total_size\n" 
    echo -e "   [1] 8.50 G    " "[2] 12.00 G    " "[3] 20.00 G\n"
    echo -e "   [4] Custom input    " "[Q] Return to workspace menu\n"
    echo -n "   Please choose the size of the SUPER package:"
    read device_size_option

    # Set the value of device_size according to the user's choice
    case "$device_size_option" in
      1)
        device_size=9126805504
        if ((device_size < total_size)); then
          echo "   Less than the reference value, please execute other options."
          continue
        fi
        break
        ;;
      2)
        device_size=12884901888
        if ((device_size < total_size)); then
          echo "   Less than the reference value, please execute other options."
          continue
        fi
        break
        ;;
      3)
        device_size=21474836480
        if ((device_size < total_size)); then
          echo "   Less than the reference value, please execute other options."
          continue
        fi
        break
        ;;
      4)
        while true; do
          echo -n "   Please enter a custom size:"
          read device_size

          if [[ "$device_size" =~ ^[0-9]+$ ]]; then
            # If the input value is less than total_size, request to re-enter
            if ((device_size < total_size)); then
              echo "   The entered value is less than the reference value, please re-enter:"
            else
              if ((device_size % 4096 == 0)); then
                break 
              else
                echo "   The entered value is not a multiple of 4096 bytes, please re-enter"
              fi
            fi
          elif [ "${device_size,,}" = "q" ]; then
            return
          else
            echo -e "\n   Invalid input, please re-enter"
          # If the input is invalid, continue the loop
          fi
        done
        break
        ;;
      Q|q)
        echo "   The packaging operation has been cancelled, return to the workspace menu."
        return
        ;;
      *)
        clear
        echo -e "\n   Invalid selection, please re-enter."
        ;;
    esac
  done

  clear # Clear the screen
  echo -e "\n"

  # Other parameters
  metadata_size="65536"
  block_size="4096"
  super_name="super"
  group_name="qti_dynamic_partitions"
  group_name_a="${group_name}_a"
  group_name_b="${group_name}_b"

# Set the value of metadata_slots according to the partition type
case "$partition_type" in
  "AB"|"VAB")
    metadata_slots="3"
    ;;
  *)
    metadata_slots="2"
    ;;
esac


# Initialize parameter string
params=""

case "$is_sparse" in
  "yes")
    params+="--sparse"
    ;;
esac

case "$partition_type" in
  "VAB")
    params+=" --group \"$group_name_a:$device_size\""
    params+=" --group \"$group_name_b:$device_size\""
    params+=" --virtual-ab"
    ;;
  "AB")
    device_size_ab=$((device_size / 2))
    params+=" --group \"$group_name_a:$device_size_ab\""
    params+=" --group \"$group_name_b:$device_size_ab\""
    ;;
  *)
    params+=" --group \"$group_name:$device_size\""
    ;;
esac


  # Get all image files in the super directory
  img_files=("$WORK_DIR/$current_workspace/Extracted-files/super/"*.img)

  # Create Packed directory (if it does not exist)
  mkdir -p "$WORK_DIR/$current_workspace/Packed"

  # Loop through each image file
  for img_file in "${img_files[@]}"; do
    # Extract the file name from the file path
    base_name=$(basename "$img_file")
    partition_name=${base_name%.*}

    # Use the stat command to get the size of the image file
    partition_size=$(stat -c%s "$img_file")

    # Set the partition group name parameter according to the partition type
    case "$partition_type" in
      "VAB")
          params+=" --partition \"${partition_name}_a:readonly:$partition_size:$group_name_a\""
          params+=" --image \"${partition_name}_a=$img_file\""
          params+=" --partition \"${partition_name}_b:readonly:0:$group_name_b\""
        ;;
      "AB")
          params+=" --partition \"${partition_name}_a:readonly:$partition_size:$group_name_a\""
          params+=" --image \"${partition_name}_a=$img_file\""
          params+=" --partition \"${partition_name}_b:readonly:$partition_size:$group_name_b\""
          params+=" --image \"${partition_name}_b=$img_file\""
        ;;
      *)
        params+=" --partition \"$partition_name:readonly:$partition_size:$group_name\""
        params+=" --image \"$partition_name=$img_file\""
        ;;
    esac
  done
              echo -e "Packing SUPER partition, waiting...\n..................\n..................\n.................."
              start=$(date +%s%N)

    eval "$TOOL_DIR/lpmake  \
      --device-size \"$device_size\" \
      --metadata-size \"$metadata_size\" \
      --metadata-slots \"$metadata_slots\" \
      --block-size \"$block_size\" \
      --super-name \"$super_name\" \
      --force-full-image \
      $params \
      --output \"$WORK_DIR/$current_workspace/Packed/super.img\"" > /dev/null 2>&1

  echo "SUPER partition has been packaged"
              end=$(date +%s%N)
              runtime=$(awk "BEGIN {print ($end - $start) / 1000000000}")
              runtime=$(printf "%.3f" "$runtime")
              echo "Time consumed: $runtime seconds"
  echo -n "Press any key to return to the workspace menu..."
  read
}

function package_super_image {
  echo -e "\n"
  mkdir -p "$WORK_DIR/$current_workspace/Extracted-files/super"
  if [ ! -d "$WORK_DIR/$current_workspace/Extracted-files/super" ]; then
    echo "   SUPER directory does not exist."
    read -n 1 -s -r -p "   Press any key to return to the workspace menu..."
    return
  fi

  # Check if there are image files in the SUPER directory
  img_files=("$WORK_DIR/$current_workspace/Extracted-files/super/"*.img)
  real_img_files=()
  for file in "${img_files[@]}"; do
    if [ -e "$file" ]; then
      real_img_files+=("$file")
    fi
  done
  if [ ${#real_img_files[@]} -lt 2 ]; then
    echo "   The SUPER directory should contain at least two image files."
    read -n 1 -s -r -p "   Press any key to return to the workspace menu..."
    return
  fi

  # Ask the user if they want to package
  while true; do
    # List all subfiles in the target directory, each file has a number in front of it
    echo -e "   SUPER sub-partitions to be packaged:\n"
    for i in "${!img_files[@]}"; do
      file_name=$(basename "${img_files[$i]}")
      printf "   \e[95m[%02d] %s\e[0m\n\n" $((i+1)) "$file_name"
    done

    echo -e "\n   [Y] Package SUPER    "  "[N] Return to workspace menu\n"
    echo -n "   Choose the function you want to execute:"
    read is_pack
    clear

    case "$is_pack" in
      Y|y)
        while true; do
          echo -e "\n   [1] OnlyA dynamic partition    "  "[2] AB dynamic partition    "  "[3] VAB dynamic partition\n"
          echo -e "   [Q] Return to workspace menu\n"
          echo -n "   Please choose your partition type:"
          read partition_type

          if [ "${partition_type,,}" = "q" ]; then  # Convert user input to lowercase
            echo "   Partition type selection cancelled, returning to workspace menu."
            return
          fi
          clear

          case "$partition_type" in
            1|2|3)
              while true; do
                echo -e "\n   [1] Sparse    "  "[2] Non-sparse\n"
                echo -e "   [Q] Return to workspace menu\n"
                echo -n "   Please choose your packaging method:"
                read is_sparse

                if [ "${is_sparse,,}" = "q" ]; then
                  echo "   Selection cancelled, returning to workspace menu."
                  return
                fi

                case "$is_sparse" in
                  1|2)
                    break 
                    ;;
                  *)
                    clear
                    echo -e "\n   Invalid selection, please re-enter."
                    ;;
                esac
              done
              break 
              ;;
            *)
              clear
              echo -e "\n   Invalid selection, please re-enter."
              # If the user input is invalid, continue the loop
              ;;
          esac
        done
        break 
        ;;
      N|n)
        echo "Packaging operation cancelled, returning to the previous menu."
        return
        ;;
      *)
        clear
        echo -e "\n   Invalid selection, please re-enter."
        # If the user input is invalid, continue the loop
        ;;
    esac
  done

  # Add your code here to handle the part after the user input
  case "$partition_type-$is_sparse" in
     1-1)
        create_super_img "OnlyA" "yes"
        ;;
     1-2)
        create_super_img "OnlyA" "no"
        ;;
     2-1)
        create_super_img "AB" "yes"
        ;;
     2-2)
        create_super_img "AB" "no"
        ;;
     3-1)
        create_super_img "VAB" "yes"
        ;;
     3-2)
        create_super_img "VAB" "no"
        ;;
    *)
      echo "   Invalid selection, please re-enter."
      ;;
  esac
}
