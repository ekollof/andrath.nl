#!/bin/ksh

# Check if a title was provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 \"Post Title\""
    exit 1
fi

# Get the post title from the first argument
title="$1"

# Generate filename from title (lowercase, replace spaces with hyphens)
# Using OpenBSD-compatible tr syntax without character classes
filename=$(echo "$title" | tr 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' 'abcdefghijklmnopqrstuvwxyz' | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//')
filename="${filename}.ms"
filepath="posts/$filename"

# Check if the file already exists
if [ -f "$filepath" ]; then
    echo "Error: $filepath already exists. Please choose a different title."
    exit 1
fi

# Get author from passwd info (OpenBSD-compatible alternative to getent)
if [ -f /etc/passwd ]; then
    author=$(grep "^${USER}:" /etc/passwd | cut -d: -f5 | cut -d, -f1)
    [ -z "$author" ] && author="$USER"
else
    author="$USER"
fi

# Get current date and time in the desired format
date=$(date "+%B %d, %Y %H:%M:%S")

# Ensure posts/ directory exists
mkdir -p posts

# Write the post template
{
    echo ".so macros.ms"
    echo ".MS"
    echo ".TL"
    echo "$title"
    echo ".AU"
    echo "$author"
    echo ".DA"
    echo "$date"
    echo ".PP"
    echo "Start writing your post here..."
} > "$filepath"

# Determine the editor to use (prefer $EDITOR, fallback to vi)
editor=${EDITOR:-vi}

# Prompt to open the file
echo "Created new post: $filepath"
printf "Would you like to open it in %s now? (y/n): " "$editor"
read answer
case "$answer" in
    [Yy]*)
        "$editor" "$filepath"
        ;;
    *)
        echo "You can edit it later with: $editor $filepath"
        ;;
esac
