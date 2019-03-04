FROM	alpine:3.9

RUN	apk add --no-cache openssl mysql-client mongodb-tools \
	# needed by awscli
	py-pip groff

RUN	pip install awscli --upgrade --no-cache-dir

RUN	addgroup -g 1000 -S user && \
	adduser -u 1000 -S user -G user

USER	user
