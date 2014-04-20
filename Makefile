PY=python
PELICAN=pelican
PELICANOPTS=

BASEDIR=$(CURDIR)
INPUTDIR=$(BASEDIR)/content
OUTPUTDIR=$(BASEDIR)/output
CONFFILE=$(BASEDIR)/pelicanconf.py
PUBLISHCONF=$(BASEDIR)/publishconf.py

S3_BUCKET=nestweb
S3_CFG=$(CURDIR)/.s3cfg
S3CMD_OPTS=--config=$(S3_CFG) --acl-public --cf-invalidate --cf-invalidate-default-index
COMPRESSED_ASSETS=theme/css/style.min.css `cd $(OUTPUTDIR) ; echo *.html` `cd $(OUTPUTDIR) ; echo **/*.html`

help:
	@echo 'Makefile for a pelican Web site                                        '
	@echo '                                                                       '
	@echo 'Usage:                                                                 '
	@echo '   make html                        (re)generate the web site          '
	@echo '   make clean                       remove the generated files         '
	@echo '   make regenerate                  regenerate files upon modification '
	@echo '   make publish                     generate using production settings '
	@echo '   make serve                       serve site at http://localhost:8000'
	@echo '   make devserver                   start/restart develop_server.sh    '
	@echo '   make stopserver                  stop local server                  '
	@echo '   ssh_upload                       upload the web site via SSH        '
	@echo '   rsync_upload                     upload the web site via rsync+ssh  '
	@echo '   dropbox_upload                   upload the web site via Dropbox    '
	@echo '   ftp_upload                       upload the web site via FTP        '
	@echo '   s3_upload                        upload the web site via S3         '
	@echo '   github                           upload the web site via gh-pages   '
	@echo '                                                                       '


html: clean $(OUTPUTDIR)/index.html

$(OUTPUTDIR)/%.html:
	$(PELICAN) $(INPUTDIR) -o $(OUTPUTDIR) -s $(CONFFILE) $(PELICANOPTS)

clean:
	[ ! -d $(OUTPUTDIR) ] || find $(OUTPUTDIR) -mindepth 1 -delete

regenerate: clean
	$(PELICAN) -r $(INPUTDIR) -o $(OUTPUTDIR) -s $(CONFFILE) $(PELICANOPTS)

serve:
	cd $(OUTPUTDIR) && $(PY) -m pelican.server

devserver:
	$(BASEDIR)/develop_server.sh restart

stopserver:
	kill -9 `cat pelican.pid`
	kill -9 `cat srv.pid`
	@echo 'Stopped Pelican and SimpleHTTPServer processes running in background.'

publish:
	$(PELICAN) $(INPUTDIR) -o $(OUTPUTDIR) -s $(PUBLISHCONF) $(PELICANOPTS)

github: publish
	ghp-import $(OUTPUTDIR)
	git push origin gh-pages

s3_clean:
	@echo "**** WARNING ****"
	@echo "Cleaning the s3 bucket containing this site."
	@echo "If you didn't mean to do this, you probably want to 'make s3_upload' sooner rather than later."
	s3cmd $(S3CMD_OPTS) sync --recursive --delete-removed fud-directory/ s3://nestweb/

s3_sync: publish compressed
	[ -e $(S3_CFG) ] || s3cmd --config=$(S3_CFG) --configure
	s3cmd $(S3CMD_OPTS) sync $(OUTPUTDIR)/ s3://$(S3_BUCKET) --no-preserve --delete-removed --add-header="Cache-Control: max-age=600,public"

compressed: publish
	cd $(OUTPUTDIR) ; for f in $(COMPRESSED_ASSETS) ; do gzip -9 $$f ; mv $$f.gz $$f ; done ; cd -

s3_compressed: compressed s3_sync
	# Put the right Content-Encoding headers on the assets that were compressed
	for f in $(COMPRESSED_ASSETS) ; do echo $$f ;  s3cmd $(S3CMD_OPTS) put $(OUTPUTDIR)/$$f s3://$(S3_BUCKET)/$$f --add-header="Cache-Control: max-age=600,public" --add-header="Content-Encoding: gzip" ; done

s3_upload: s3_compressed


.PHONY: html help clean regenerate serve devserver publish github s3_upload s3_sync s3_compressed compressed
