- access https://xiaogliu.github.io/export-arc-bookmarks/

- cp ~/Library/Application Support/Arc/StorableSidebar.json ~/

- 將 Read Space 下 hyperlink table 語法複製出來

- sed -E 's/<DT><A HREF="([^"]+)">([^<]+)<\/A><\/DT>/\2\n\1\n----/' tmp2.txt > output.txt

- while IFS= read -r title; do
  read -r url
  read -r sep
  md5=$(printf '%s' "$url" | md5 | cut -d' ' -f1)
  printf "%s\n%s\n%s\n----\n" "$title" "$url" "$md5"
done < output.txt > output_with_md5.txt

