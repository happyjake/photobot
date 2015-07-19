FROM ubuntu

RUN apt-get update
RUN apt-get upgrade -y

RUN apt-get install -y language-pack-en
ENV LANGUAGE en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8

RUN locale-gen en_US.UTF-8
RUN dpkg-reconfigure locales

RUN apt-get install -y ruby
RUN \
  /bin/bash -l -c 'gem install flickraw-cached micro-optparse exifr'

RUN mkdir -p /root/photobot/
ADD ./config.json /root/photobot/
ADD ./sync.rb /root/photobot/

CMD ["/root/photobot/sync.rb"]
