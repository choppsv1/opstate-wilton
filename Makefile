#Crazy makefile authored by Lou Berger <lberger@labn.net>
#The author makes no claim/restriction on use.  It is provided "AS IS".

DRAFT  = draft-wilton-netmod-opstate-yang

MODELS = # Models to be extracted normally go here.

#assumes standard yang modules installed in ../yang, customize as needed
#  e.g., based on a 'cd .. ; git clone https://github.com/YangModels/yang.git'
YANGIMPORT_BASE = ../yang
PLUGPATH    := $(shell echo `find $(YANGIMPORT_BASE) -name \*.yang | sed 's,/[a-z0-9A-Z@_\-]*.yang$$,,' | uniq` | tr \  :)
PYTHONPATH  := $(shell echo `find /usr/lib* /usr/local/lib* -name  site-packages ` | tr \  :)
WITHXML2RFC := $(shell which xml2rfc > /dev/null 2>&1 ; echo $$? )

ID_DIR	     = IDs
REVS	    := $(shell sed -e '/docName="/!d;s/.*docName="\([^"]*\)".*/\1/' $(DRAFT).xml | \
		 awk -F- '{printf "%02d %02d",$$NF-1,$$NF}')
PREV_REV    := $(word 1, $(REVS))
REV	    := $(word 2, $(REVS))
OLD          = $(ID_DIR)/$(DRAFT)-$(PREV_REV)
NEW          = $(ID_DIR)/$(DRAFT)-$(REV)

TREES := $(MODELS:.yang=.tree)


%.tree: %.yang
	@echo Updating $< revision date
	@rm -f $<.prev; cp -pf $< $<.prev 
	@sed 's/revision.\"[0-9]*\-[0-9]*\-[0-9]*\"/revision "'`date +%F`'"/' < $<.prev > $<
	@diff $<.prev $< || exit 0
	@echo Generating $@	
	@PYTHONPATH=$(PYTHONPATH) pyang --ietf -f tree -p $(PLUGPATH) $< > $@  || exit 0

%.txt: %.xml
	@if [ $(WITHXML2RFC) == 0 ] ; then 	\
		rm -f $@.prev; cp -pf $@ $@.prev ; \
		xml2rfc $< 			; \
		diff $@.prev $@ || exit 0 	; \
	fi

%.html: %.xml
	@if [ $(WITHXML2RFC) == 0 ] ; then 	\
		rm -f $@.prev; cp -pf $@ $@.prev ; \
		xml2rfc --html $< 		; \
	fi

all:	$(TREES) $(DRAFT)-$(REVISION).txt $(DRAFT)-$(REVISION).html

clean:
	rm -rf $(DRAFT).txt $(DRAFT).html IDs *.prev

vars:
	echo PYTHONPATH=$(PYTHONPATH)
	echo PLUGPATH=$(PLUGPATH)
	echo PREV_REV=$(PREV_REV)
	echo REV=$(REV)
	echo OLD=$(OLD)

$(DRAFT).xml: $(MODELS)
	@rm -f $@.prev; cp -p $@ $@.prev
	@for model in $? ; do \
		rm -f $@.tmp; cp -p $@ $@.tmp	 		 	; \
		echo Updating $@ based on $$model		 	; \
		base=`echo $$model | cut -d. -f 1` 		 	; \
		echo $${base};\
		start_stop=(`awk 'BEGIN{pout=1}				\
			/^<CODE BEGINS> file .'$${base}'/ 		\
				{pout=0; print NR-1;} 			\
			pout == 0 && /^<CODE E/ 			\
				{pout=1; print NR;}' $@.tmp`) 		; \
		head -$${start_stop[0]}    $@.tmp    		> $@	; \
		echo '<CODE BEGINS> file "'$${base}'@'`date +%F`'.yang"'>> $@;\
		cat $$model					>> $@	; \
		tail -n +$${start_stop[1]} $@.tmp 		>> $@	; \
		rm -f $@.tmp 		 				; \
	done
	diff -bw $@.prev $@ || exit 0

# Fill in current month and year
# M=$(date +%B); Y=$(date +%Y); sed -i -e "/<date[^/]*\/>/s,<date[^/]*/>,<date month=\"$M\" year=\"$Y\"/>," $@

$(DRAFT)-diff.txt: $(DRAFT).txt 
	@echo "Generating diff of $(OLD).txt and $(DRAFT).txt > $@..."
	if [ -f  $(OLD).txt ] ; then \
		sdiff --ignore-space-change --expand-tabs -w 168 $(OLD).txt $(DRAFT).txt | \
		cut -c84-170 | sed 's/. *//'  \
		| grep -v '^ <$$' | grep -v '^<$$' > $@ ;\
	 fi

idnits: $(DRAFT).txt
	@if [ ! -f idnits ] ; then \
		-rm -f $@ 					;\
		wget http://tools.ietf.org/tools/idnits/idnits	;\
		chmod 755 idnits				;\
	fi
	idnits $(DRAFT).txt

id: $(DRAFT).txt $(DRAFT).html
	@if [ ! -e $(ID_DIR) ] ; then \
		echo "Creating $(ID_DIR) directory" 	;\
		mkdir $(ID_DIR) 			;\
		git add $(ID_DIR)			;\
	fi
	@if [ -f "$(NEW).xml" ] ; then \
		echo "" 				;\
		echo "$(NEW).xml already exists, not overwriting!" ;\
		diff -sq $(DRAFT).xml  $(NEW).xml 	;\
		echo "" 				;\
	else \
		echo "Copying to $(NEW).{xml,txt,html}" ;\
		echo "" 				;\
		cp -p $(DRAFT).xml $(NEW).xml  		;\
		cp -p $(DRAFT).txt $(NEW).txt  		;\
		cp -p $(DRAFT).html $(NEW).html  	;\
		git add $(NEW).xml $(NEW).txt  $(NEW).html ;\
		ls -lt $(DRAFT).* $(NEW).* 		;\
	fi

rmid:
	@echo "Removing:"
	@ls -l $(NEW).xml $(NEW).txt  $(NEW).html
	@echo -n "Hit <ctrl>-C to abort, or <CR> to continue: "
	@read t
	@rm -f $(NEW).xml $(NEW).txt $(NEW).html
	@git rm  $(NEW).xml $(NEW).txt $(NEW).html
