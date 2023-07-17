#!/bin/bash 
#=================================================================# 
#  System Required: android zerotermux                           # 
#  Description: FFmpeg Stream Media Server3.5                    # 
#  Author: linzimo                                               # 
#  Website:linzimo.com
#  2023.7.17                                                      # 
#=================================================================# 
red='\033[0;31m' 
green='\033[0;32m' 
yellow='\033[0;33m' 
font="\033[0m" 
 
read -p "请输入要播放的文件夹路径(可编辑源代码设置默认路径，格式仅支持mp4,并且要绝对路径,例如/opt/video): " folder 
folder=${folder:-/storage/emulated/0/1aaab/怪诞小镇} 
echo "您输入的路径为：$folder" 

read -p "推流地址和推流码" rtmp
rtmp=${rtmp:-rtmp://192.168.6.184/live/stream}
#rtmp=${rtmp:-rtmp://a.rtmp.youtube.com/live2/}

# 相关日志文件字体 
log_file="$folder/log.txt"
time_log_file="$folder/time_log_file.txt"
retry_time_log_file="$folder/retry_time_log_file.txt" 
fontfile="$folder/优设好身体.ttf" 
start_time_file="/storage/emulated/0/1aaab/怪诞小镇/time_d.txt"
 
video_list=($(find "$folder" -type f -name "*.mp4" | sort)) 
#获取日志开始视频 
if [ -e "$log_file" ]; then 
    last_video=$(tail -n 1 "$log_file") 
    # 添加最后一个视频为空的判断，避免脚本执行失败 
    if [ -z "$last_video" ]; then 
        start_index=0 
    else 
        for ((i=${#video_list[@]}-1;i>=0;i--)); do 
            video="${video_list[$i]}" 
            filename=$(basename "$video" .mp4) 
 
            if [ "$filename" = "$last_video" ]; then 
                start_index=$((i+1)) 
                break 
            fi 
        done 
    fi 
else 
    start_index=0 
fi 
#获取视频时长 
get_duration() { 
    DURATION=$(ffprobe -i "$1" -show_entries format=duration -v quiet -of csv="p=0") 
    if [ -n "$DURATION" ]; then 
        DURATION=${DURATION%.*} 
        HOURS=$((DURATION / 3600)) 
        MINS=$(( (DURATION % 3600) / 60 )) 
        SECS=$(( DURATION % 60 )) 
        echo "${HOURS}:${MINS}:${SECS}" 
    fi 
} 
#每一次第一次推流与重试推流时间日志相加时间戳 
function addTimestamps { 
    local t1=${1:-00:00:00.00} 
    local t2=${2:-00:00:00.00} 
 
    local h1=$(echo "$t1" | cut -d':' -f1) 
    local m1=$(echo "$t1" | cut -d':' -f2) 
    local s1=$(echo "$t1" | cut -d':' -f3 | sed 's/\.[0-9]*//') 
    local h2=$(echo "$t2" | cut -d':' -f1) 
    local m2=$(echo "$t2" | cut -d':' -f2) 
    local s2=$(echo "$t2" | cut -d':' -f3 | sed 's/\.[0-9]*//') 
 
    local total=$((10#${h1}*3600 + 10#${m1}*60 + 10#${s1} + 10#${h2}*3600 + 10#${m2}*60 + 10#${s2})) 
    local h=$(printf "%02d" $((total / 3600))) 
    local m=$(printf "%02d" $(((total / 60) % 60))) 
    local s=$(printf "%02d" $((total % 60))) 
 
    echo "${h}:${m}:${s}.00" 
} 
 
while true; do 
    for ((i=$start_index;i<${#video_list[@]};i++)); do 
        video="${video_list[$i]}" 
        filename="$(basename "$video" .mp4)"
	start_time=$(grep -o "$filename+[^ ]*" "$start_time_file" | awk -F'+' '{print $2}')
	formatted_time=$(printf "%02d:%02d:%02d" $(echo $start_time | tr ":" " "))

        ffmpeg_command="-vf "drawtext=text=$filename:x=20:y=20:fontsize=25:fontcolor=white@0.8:fontfile=$fontfile:shadowx=1:shadowy=2:shadowcolor=#6284FF,drawtext=text=:x=300:y=20:fontsize=25:fontcolor=white@0.8:fontfile=$fontfile:shadowx=2:shadowy=2:shadowcolor=#6284FF" -preset ultrafast -vcodec libx264 -r 30 -g 70 -b:v 2500k -c:a aac -b:a 200k -strict -2 -f flv ${rtmp}" 
        for retry_count in {0..20}; do 
            if [ $retry_count -eq 0 ]; then 
                # 第一次推流 
                nowtime=$(date '+%d日%H时%M分') 
                duration=$(get_duration "$video") 
                #> $time_log_file
		start_time=$(grep -o "$filename+[^ ]*" "$start_time_file" | awk -F'+' '{print $2}')
		#格式化为标准格式时间
		formatted_time=$(printf "%02d:%02d:%02d" $(echo $start_time | tr ":" " "))
		echo "$formatted_time" >> "$retry_time_log_file"
		echo "$formatted_time" >> "$time_log_file"
		cowsay 开始推流喽 当前时间:$nowtime 视频长度:$duration 开始时间:$formatted_time

                echo -e "${green}------<正在开始>-<开始点:$formatted_time>-<视频总长:$duration>--<>$filename${font}"
		if ffmpeg -ss $formatted_time -re -i "$video" $ffmpeg_command 2> >(grep -o "time=[^ ]*" | sed 's/time=//' >> "$time_log_file"); then
                    echo "$filename" >> "$log_file"
		    >$time_log_file
                    break
                fi
		else
                # 重试时从之前的记时间开始播放 
                if [ -e "$time_log_file" ]; then
			nowtime=$(date '+%d日%H时%M分') 
                    log_time=$(tail -n 1 "$time_log_file")
		    sleep 6
                    echo -e "${yellow}--<重试次数:$retry_count>--<当前时间:$nowtime>--<开始点:$log_time>--<>$filename${font}"
		    if ffmpeg -ss $log_time -re -i "$video" $ffmpeg_command 2> >(grep -o "time=[^ ]*" | sed 's/time=//' >> "$retry_time_log_file"); then

			    #2> >(grep -Ei 'error|failed|cannot|timeout|Unable'); then 
                        echo "$filename" >> "$log_file" 
                        break 
                    else 
                        ti1=$(tail -n 1 "$time_log_file")
                        ti2=$(tail -n 1 "$retry_time_log_file")
                        log_time=$(addTimestamps "$ti1" "$ti2") 
                	> $retry_time_log_file
			echo "开始点 $ti1"
			echo "重试了 $ti2"
			echo "相加后 $log_time"
                        echo "$log_time" >> "$time_log_file" 
                    fi 
                else 
                    #时间日志为空,直接从头开始 
                    echo -e "${yellow}--<$retry_count>-<重头>-<$nowtime>--$filename${font}" 
                    if ffmpeg -i "$video" $ffmpeg_command 2> >(grep -o "time=[^ ]*" | sed 's/time=//' >> "$retry_time_log_file"); then
                        echo "$filename" >> "$log_file" 
                        break 
                    fi 
                fi 
            fi 
            # 重试10
            if (( retry_count < 20)); then
                echo "________________________等待6s___________________"
            else 
               echo -e "${red}------<跳过>--<$nowtime>------ $filename${font}" 

                # 在多次尝试后仍然失败则跳出循环继续执行下一个视频 
                break 
            fi 
        done 
    done 
    > $log_file 
    # 获取新的视频列表#重置开始索引
    video_list=($(find "$folder" -type f -name "*.mp4" | sort)) 
    start_index=0 
done
