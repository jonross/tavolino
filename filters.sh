
# Relatively simple line-based filters that act on stdin.

# Convert \r to \n

crnl() {
    tr \\015 \\012
}

# Convert tabs or spaces to one space

narrow() {
    tr -s ' \011' '  '
}

# Remove \r

nocr() {
    tr -d \\015
}

# Remove \n

nonl() {
    tr -d \\012
}

# Reverse order of lines

reverse() {
    perl -e 'print reverse <STDIN>'
}

# Trim lines to designated length

trimto() {
    perl -lpe "substr(\$_, $1) = '' if length > $1"
}

