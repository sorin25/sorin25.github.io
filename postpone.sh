start_date_ts=$(date -d"$1" +%s)\

#date -d"@$start_date_ts"

weeks_delay=$2
find _posts -type f -print0 | sort -z | while IFS= read -r -d $'\0' f; do 
    IFS=$'\t' read -r post_date title < <(echo $f | sed 's/_posts\///; s/-/\t/3')
    TS=$(date -d "$post_date" +%s)
    if [ $TS -lt $start_date_ts ]; then
        continue;
    fi
    new_date=$(date -d"$post_date + $weeks_delay weeks" +"%Y-%m-%d")
    git mv "_posts/$post_date-$title" "_posts/$new_date-$title"
 done