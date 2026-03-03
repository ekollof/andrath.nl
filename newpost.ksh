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
slug=$(echo "$title" | tr 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' 'abcdefghijklmnopqrstuvwxyz' | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//')

# Guard against an empty or degenerate slug (e.g. all non-ASCII title)
if [ -z "$slug" ] || [ "$slug" = "-" ]; then
    echo "Error: Could not generate a valid filename slug from title: $title" >&2
    echo "Please use a title that contains at least one ASCII letter or digit." >&2
    exit 1
fi

filename="${slug}.ms"
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
date=$(LC_ALL=en_US.UTF-8 date "+%B %d, %Y %H:%M:%S")

# Prompt for tags
printf "Enter tags (comma-separated, e.g. openbsd, unix): "
read tags_input

# Ensure posts/ directory exists
mkdir -p posts

# Write the post template
{
    printf '%s\n' ".so macros.ms"
    printf '%s\n' ".MS"
    printf '%s\n' ".TL"
    printf '%s\n' "$title"
    printf '%s\n' ".AU"
    printf '%s\n' "$author"
    printf '%s\n' ".DA"
    printf '%s\n' "$date"
    if [ -n "$tags_input" ]; then
        printf '%s\n' ".TAG"
        printf '%s\n' "$tags_input"
    fi
    printf '%s\n' ".PP"
    printf '%s\n' "Start writing your post here..."
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
