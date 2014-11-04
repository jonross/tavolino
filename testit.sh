
set -e

verify() {
    if [[ "$(cat $1)" != "$2" ]]; then
        echo "Failed test of $SUBJECT -- in $1 expected"
        echo "$2"
        echo "but was"
        cat $1
        return 1
    fi
}

trap "rm -f a.txt b.txt" 0

. ./filters.sh
. ./utils.sh

SUBJECT=crnl
echo axb | tr x \\015 >a.txt
echo fooxbar | tr x \\015 >b.txt
apply crnl a.txt b.txt
verify a.txt "$(echo axb | tr x \\012)"
verify b.txt "$(echo fooxbar | tr x \\012)"

SUBJECT=narrow
cat >a.txt <<!
  abc    def g		h i
j  k  l  m  n
!
apply narrow a.txt
verify a.txt " abc def g h i
j k l m n"

SUBJECT=nocr
echo axbxc-dxexf | tr x- \\015\\012 >a.txt
apply nocr a.txt
verify a.txt "abc
def"

SUBJECT=nonl
echo axbxc-dxexf | tr x \\012 >a.txt
apply nonl a.txt
verify a.txt abc-def

SUBJECT=reverse
cat >a.txt <<!

!
cat >b.txt <<!
this is
a
test
!
apply reverse a.txt b.txt
verify a.txt ""
verify b.txt "test
a
this is"

SUBJECT=trimto
cat >a.txt <<!
these lines are
longer than
five chars
!
apply "trimto 5" a.txt
verify a.txt "these
longe
five "
