
test(<<headtail under 10 lines>>, <<headtail>>, m4_substr(ls1,0,30), <<
[
bash
cat
chmod
cp
csh
date
>>, <<>>)

test(<<headtail under 20 lines>>, <<headtail>>, m4_substr(ls1,0,60), <<
[
bash
cat
chmod
cp
csh
date
dd
df
domainname
--
echo
ed
expr
>>, <<>>)

test(<<headtail over 20 lines>>, <<headtail>>, ls1, <<
[
bash
cat
chmod
cp
csh
date
dd
df
domainname
--
rm
rmdir
sh
sleep
stty
sync
tcsh
unlink
wait4path
zsh
>>, <<>>)

