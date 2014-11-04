
all:	.all

.all:	*.sh *.py
	sh testit.sh
	touch .all

clean:
	rm -f .all

