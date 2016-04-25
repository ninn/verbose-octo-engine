#!/bin/sh
# This script saves your soup including enclosures. See below.

if [ "X$1" = "X" ] || [ "X$1" = "X-h" ]; then
  echo "
This script saves your soup including enclosures and might kill your cat
(laughing or not.) A little .sh by neingeist (http://nein.gei.st.)

Usage: 

  $0 http://www.soup.io/export/dead23cafe42babe17n0n00b.rss

Call the script with your soup export RSS URL as the single argument. To
determine the export URL: Go to your soup, login, and open the options panel.
You'll find the export URL under 'Privacy'.

The export RSS file and the enclosures will be saved in your current working
directory. This script requires wget and xsltproc.

https://github.com/neingeist/soup-backup
"
  exit
fi

set -e
SOUPNAME="$1"
SAVEDIR="/media/ninn/soup_download/$SOUPNAME/"
EXPORTURL="$2"

# Beware of my XSLT kung fu. 
xsl='<?xml version="1.0"?>
<stylesheet version="1.0"
  xmlns="http://www.w3.org/1999/XSL/Transform">
  <output method="text"/>
  <template match="/">
    <apply-templates select="/rss/channel/item/enclosure"/>
  </template>
  <template match="enclosure">
    <value-of select="@url"/><text>&#10;</text>
  </template>
</stylesheet>'
xslfile=$(mktemp /tmp/soup-backup.xsl.XXXXXX)
echo "$xsl" > "$xslfile"


# Save export RSS
cd "$SAVEDIR"
echo "Saving export RSS..."

if ! wget -t 100 -nv -O backup.rss -q "$EXPORTURL"; then
  echo "oops. something wrong with wget:" >&2
  ls -l backup.rss >&2
  exit 1
fi

if ! test -s backup.rss; then
  echo "oops. something wrong:" >&2
  ls -l backup.rss >&2
  exit 1
fi
cp backup.rss backup.rss.$(date +%Y%m%d)

# Delete old export RSS files
 find . -maxdepth 1 -type f -and -name "backup.rss.*" \
  -and -mtime +30 -exec rm -f {} \;

# Fetch enclosures
mkdir -p enclosures/
cd enclosures/ 
xsltproc "$xslfile" ../backup.rss | while read url; do
  # Determine and check filename
  file=`echo "$url" | sed "s#.*/##"`
  if ! echo "$file" | egrep -q "^[a-zA-Z0-9._-]+$"; then
    echo "Illegal filename '$file'." >&2
  else
    # Download if necessary
    if ! test -f "$file"; then
      echo "Saving enclosure $url..."
      filetmp=`mktemp /tmp/soup-backup.XXXXXX`

      if wget -O"$filetmp" -q "$url"; then
        mv "$filetmp" "$file"
      else 
        rm -f "$filetmp"
        echo "Could not download $url." >&2
      fi
#    else
#	echo "File already downloaded"
    fi
  fi
done

# Cleanup
rm -f "$xslfile"
echo "Done."
