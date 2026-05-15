#!/bin/bash

# Verify RSS feeds from an OPML file
# Usage: ./verify-feeds.sh [opml-file]

OPML_FILE="${1:-.opml}"
TIMEOUT=10
WORKING=0
BROKEN=0
FAILED=0

if [[ ! -f "$OPML_FILE" ]]; then
    echo "Error: File not found: $OPML_FILE"
    exit 1
fi

echo "Verifying RSS feeds from: $OPML_FILE"
echo "============================================"

# Use sed to join multi-line XML elements, then extract RSS feeds
while IFS= read -r line; do
    # Extract xmlUrl
    if [[ $line =~ xmlUrl=\"([^\"]+)\" ]]; then
        url="${BASH_REMATCH[1]}"
        
        # Decode HTML entities
        url="${url//&amp;/&}"
        url="${url//&quot;/\"}"
        url="${url//&lt;/\<}"
        url="${url//&gt;/\>}"
        
        # Get feed title from text attribute
        if [[ $line =~ text=\"([^\"]+)\" ]]; then
            title="${BASH_REMATCH[1]}"
        else
            title="Unknown"
        fi
    fi
    
    # Test the feed with curl (follow redirects with -L)
    response_code=$(curl -s -o /dev/null -w "%{http_code}" \
        -L \
        -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
        --connect-timeout $TIMEOUT \
        --max-time $TIMEOUT \
        "$url" 2>/dev/null)
    
    if [[ $response_code == "200" ]]; then
        echo "✓ [200] $title"
        ((WORKING++))
    elif [[ $response_code == "301" ]] || [[ $response_code == "302" ]]; then
        echo "✓ [$response_code] $title"
        ((WORKING++))
    elif [[ $response_code =~ ^[3-9][0-9]{2}$ ]]; then
        echo "⚠ [$response_code] $title"
        ((FAILED++))
    else
        echo "✗ [TIMEOUT/ERROR] $title"
        ((BROKEN++))
    fi
done < <(sed ':a;N;$!ba;s/\n//g' "$OPML_FILE" | grep -o '<outline[^>]*type="rss"[^>]*/>')
echo "============================================"
echo "Results:"
echo "  Working: $WORKING"
echo "  Issues:  $FAILED"
echo "  Broken:  $BROKEN"
echo "  Total:   $((WORKING + FAILED + BROKEN))"
