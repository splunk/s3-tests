FROM python:2

WORKDIR /s3-tests

RUN apt-get install -y libevent-dev libxml2-dev libxslt-dev zlib1g-dev
COPY . .

# slightly old version of setuptools; newer fails w/ requests 0.14.0
RUN pip install --upgrade pip
RUN pip install setuptools==32.3.1
RUN pip install -r requirements.txt

# bypass the bootstrap script that uses virtualenv, which isn't necessary since
# we're in a container with all dependencies installed directly
RUN python setup.py develop

ENV S3TEST_CONF=/s3-tests/splunk.conf

ENTRYPOINT ["nosetests"]
CMD ["-a", "!skip_for_splunk"]
